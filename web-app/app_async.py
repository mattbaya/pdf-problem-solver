from flask import Flask, request, render_template, send_file, jsonify
import os
import subprocess
import tempfile
import shutil
from werkzeug.utils import secure_filename
import uuid
import threading
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
import time
import re

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB max file size
app.config['UPLOAD_FOLDER'] = '/tmp/pdf-uploads'
# SERVER_NAME should not be hardcoded - it's derived from the request

# Security headers
@app.after_request
def add_security_headers(response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    response.headers['Content-Security-Policy'] = "default-src 'self'; script-src 'unsafe-inline' 'self'; style-src 'unsafe-inline' 'self'"
    return response

# Ensure upload directory exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

ALLOWED_EXTENSIONS = {'pdf'}
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB
MAX_FILENAME_LENGTH = 255
CLEANUP_AGE = 86400  # Clean files older than 24 hours (in seconds)

# Store processing jobs in memory (in production, use Redis or database)
processing_jobs = {}

# Rate limiting: track uploads per IP
upload_attempts = {}
MAX_UPLOADS_PER_IP = 5
RATE_LIMIT_WINDOW = 3600  # 1 hour

def cleanup_old_files():
    """Remove files older than CLEANUP_AGE seconds"""
    try:
        if not os.path.exists(app.config['UPLOAD_FOLDER']):
            return

        now = time.time()
        for filename in os.listdir(app.config['UPLOAD_FOLDER']):
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            if os.path.isfile(filepath):
                file_age = now - os.path.getmtime(filepath)
                if file_age > CLEANUP_AGE:
                    try:
                        os.remove(filepath)
                    except:
                        pass  # Ignore errors (file might be in use)
    except:
        pass  # Ignore cleanup errors

def validate_email(email):
    """Validate email format to prevent injection"""
    if not email or len(email) > 254:  # Max email length
        return False

    # RFC 5322 simplified regex
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(pattern, email):
        return False

    # Additional security: block common malicious patterns
    dangerous_chars = ['<', '>', '\\', '/', '|', ';', '&', '$', '`']
    if any(char in email for char in dangerous_chars):
        return False

    return True

def allowed_file(filename):
    """Validate file extension"""
    if not filename or '.' not in filename:
        return False

    ext = filename.rsplit('.', 1)[1].lower()
    return ext in ALLOWED_EXTENSIONS

def check_rate_limit(ip_address):
    """Simple rate limiting per IP"""
    current_time = time.time()

    # Clean old entries
    for ip in list(upload_attempts.keys()):
        upload_attempts[ip] = [t for t in upload_attempts[ip]
                              if current_time - t < RATE_LIMIT_WINDOW]
        if not upload_attempts[ip]:
            del upload_attempts[ip]

    # Check current IP
    if ip_address not in upload_attempts:
        upload_attempts[ip_address] = []

    if len(upload_attempts[ip_address]) >= MAX_UPLOADS_PER_IP:
        return False

    upload_attempts[ip_address].append(current_time)
    return True

def send_email(to_email, subject, body):
    """Send email via local Postfix"""
    try:
        msg = MIMEMultipart()
        msg['From'] = 'noreply@dev.svaha.com'
        msg['To'] = to_email
        msg['Subject'] = subject

        msg.attach(MIMEText(body, 'html'))

        # Connect to local Postfix
        with smtplib.SMTP('localhost', 25) as server:
            server.send_message(msg)

        return True
    except Exception as e:
        print(f"Email error: {e}")
        return False

def process_pdf_async(job_id, input_path, output_path, email, pages_mode, custom_pages, dpi,
                      do_ocr, add_page_numbers, compress, remove_security, request_host):
    """Process PDF in background thread"""
    try:
        processing_jobs[job_id]['status'] = 'processing'
        processing_jobs[job_id]['progress'] = 'Processing your PDF...'

        current_file = input_path

        # Step 1: Remove security if requested
        if remove_security:
            processing_jobs[job_id]['progress'] = 'Removing security restrictions...'
            unlock_script = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                       'additional-tools', 'unlock-pdf.sh')

            result = subprocess.run(
                [unlock_script, current_file],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            expected_unlocked = current_file.replace('.pdf', '-unlocked.pdf')
            if os.path.exists(expected_unlocked):
                if current_file != input_path:
                    os.remove(current_file)
                current_file = expected_unlocked

        # Step 2: Fix PDF fonts (main processing)
        processing_jobs[job_id]['progress'] = 'Converting PDF pages to high-resolution images...'
        script_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                 'fix-pdf-fonts-interactive.sh')

        cmd = [script_path, current_file, '--dpi', dpi]

        if pages_mode == 'custom' and custom_pages:
            pages = custom_pages.replace(',', ' ')
            cmd.extend(['--pages', pages])
        else:
            cmd.extend(['--pages', pages_mode])

        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            stdin=subprocess.PIPE,
            text=True
        )

        stdout, stderr = process.communicate(input=f"y\n{output_path}\ny\n")

        if process.returncode != 0:
            processing_jobs[job_id]['status'] = 'failed'
            error_msg = stderr if stderr else f"Script exited with code {process.returncode}. Check logs for details."
            processing_jobs[job_id]['error'] = error_msg

            if email:
                send_email(email, 'PDF Processing Failed',
                    f'''<html><body>
                    <h2>PDF Processing Failed</h2>
                    <p>Unfortunately, your PDF processing job failed.</p>
                    <p><strong>Error:</strong> {error_msg}</p>
                    </body></html>''')
            return

        # Find the output file
        auto_output = current_file.replace('.pdf', '-FIXED.pdf')
        if os.path.exists(auto_output):
            if current_file != input_path:
                os.remove(current_file)
            current_file = auto_output
        elif os.path.exists(output_path):
            if current_file != input_path:
                os.remove(current_file)
            current_file = output_path
        else:
            processing_jobs[job_id]['status'] = 'failed'
            processing_jobs[job_id]['error'] = 'Output file was not created'
            return

        # Step 3: OCR if requested
        if do_ocr:
            processing_jobs[job_id]['progress'] = 'Running OCR...'
            ocr_script = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                    'additional-tools', 'ocr-and-index.sh')

            result = subprocess.run(
                [ocr_script, current_file, '--full-ocr'],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            expected_ocr = current_file.replace('.pdf', '-OCR.pdf')
            if os.path.exists(expected_ocr):
                os.remove(current_file)
                current_file = expected_ocr

        # Step 4: Add page numbers if requested
        if add_page_numbers:
            processing_jobs[job_id]['progress'] = 'Adding page numbers...'
            pagenums_script = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                         'additional-tools', 'add-page-numbers.sh')

            result = subprocess.run(
                [pagenums_script, current_file],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            expected_numbered = current_file.replace('.pdf', '-numbered.pdf')
            if os.path.exists(expected_numbered):
                os.remove(current_file)
                current_file = expected_numbered

        # Step 5: Compress if requested
        if compress:
            processing_jobs[job_id]['progress'] = 'Compressing PDF...'
            compress_script = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                         'additional-tools', 'compress-pdf.sh')

            result = subprocess.run(
                [compress_script, current_file, 'ebook'],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            expected_compressed = current_file.replace('.pdf', '-compressed.pdf')
            if os.path.exists(expected_compressed):
                os.remove(current_file)
                current_file = expected_compressed

        # Move to final output path
        shutil.move(current_file, output_path)

        # Mark as completed
        processing_jobs[job_id]['status'] = 'completed'
        processing_jobs[job_id]['completed_at'] = datetime.now().isoformat()

        # Send success email if provided
        if email:
            download_url = f"https://{request_host}/download/{job_id}"
            send_email(email, 'PDF Processing Complete',
                f'''<html><body>
                <h2>Your PDF is Ready!</h2>
                <p>Your PDF has been successfully processed and is ready for download.</p>
                <p><a href="{download_url}" style="display:inline-block;padding:10px 20px;background-color:#3498db;color:white;text-decoration:none;border-radius:5px;">Download Fixed PDF</a></p>
                <p>This link will be available for 24 hours.</p>
                <p><small>File: {processing_jobs[job_id]['filename']}</small></p>
                </body></html>''')

    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"ERROR in process_pdf_async for job {job_id}: {error_details}", flush=True)

        processing_jobs[job_id]['status'] = 'failed'
        processing_jobs[job_id]['error'] = str(e)

        if email:
            send_email(email, 'PDF Processing Failed',
                f'''<html><body>
                <h2>PDF Processing Failed</h2>
                <p>An unexpected error occurred: {str(e)}</p>
                </body></html>''')
    finally:
        # Clean up input file
        if os.path.exists(input_path):
            os.remove(input_path)

@app.route('/')
def index():
    cleanup_old_files()  # Run cleanup on each request
    return render_template('index_async.html')

@app.route('/upload', methods=['POST'])
def upload_file():
    # Get client IP
    client_ip = request.headers.get('X-Forwarded-For', request.remote_addr)
    if ',' in client_ip:
        client_ip = client_ip.split(',')[0].strip()

    # Rate limiting
    if not check_rate_limit(client_ip):
        return jsonify({'error': 'Too many upload attempts. Please try again later.'}), 429

    # Get parameters from form
    email = request.form.get('email', '').strip()
    pages_mode = request.form.get('pages', 'all')
    custom_pages = request.form.get('custom_pages', '')
    dpi = request.form.get('dpi', '600')

    # Get processing options
    do_ocr = request.form.get('ocr', '') == '1'
    add_page_numbers = request.form.get('page_numbers', '') == '1'
    compress = request.form.get('compress', '') == '1'
    remove_security = request.form.get('remove_security', '') == '1'

    # Validate DPI
    if dpi not in ['300', '600', '1200']:
        dpi = '600'

    # Email is optional now
    if email and not validate_email(email):
        return jsonify({'error': 'Invalid email address format'}), 400

    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400

    if file and allowed_file(file.filename):
        # Validate file size (double check since MAX_CONTENT_LENGTH should catch this)
        file.seek(0, os.SEEK_END)
        file_size = file.tell()
        file.seek(0)

        if file_size > MAX_FILE_SIZE:
            return jsonify({'error': 'File size exceeds 100MB limit'}), 400

        if file_size == 0:
            return jsonify({'error': 'File is empty'}), 400

        # Sanitize filename and validate length
        original_filename = file.filename
        if len(original_filename) > MAX_FILENAME_LENGTH:
            return jsonify({'error': 'Filename is too long'}), 400

        # Generate unique job ID
        job_id = str(uuid.uuid4())

        # Double sanitization: werkzeug's secure_filename + additional validation
        filename = secure_filename(original_filename)
        if not filename or filename == '':
            filename = 'document.pdf'

        # Ensure filename ends with .pdf
        if not filename.lower().endswith('.pdf'):
            filename += '.pdf'

        # Build paths - ensure they're within UPLOAD_FOLDER (prevent path traversal)
        input_path = os.path.abspath(os.path.join(app.config['UPLOAD_FOLDER'], f"{job_id}_{filename}"))
        output_path = os.path.abspath(os.path.join(app.config['UPLOAD_FOLDER'], f"{job_id}_fixed_{filename}"))

        # Security check: ensure paths are within UPLOAD_FOLDER
        if not input_path.startswith(os.path.abspath(app.config['UPLOAD_FOLDER'])):
            return jsonify({'error': 'Invalid file path'}), 400
        if not output_path.startswith(os.path.abspath(app.config['UPLOAD_FOLDER'])):
            return jsonify({'error': 'Invalid file path'}), 400

        file.save(input_path)

        # Create job entry
        processing_jobs[job_id] = {
            'filename': f"fixed_{filename}",
            'email': email,
            'status': 'queued',
            'created_at': datetime.now().isoformat(),
            'output_path': output_path
        }

        # Start background processing
        thread = threading.Thread(
            target=process_pdf_async,
            args=(job_id, input_path, output_path, email, pages_mode, custom_pages, dpi,
                  do_ocr, add_page_numbers, compress, remove_security, request.host)
        )
        thread.daemon = True
        thread.start()

        # Return job info for status polling
        return jsonify({
            'success': True,
            'job_id': job_id,
            'download_id': job_id,  # For compatibility with template
            'filename': f"fixed_{filename}",
            'message': 'PDF processing started.' + (' You will receive an email when it\'s ready.' if email else '')
        })

    return jsonify({'error': 'Invalid file type. Only PDF files are allowed.'}), 400

@app.route('/status/<job_id>')
def job_status(job_id):
    """Check job status"""
    # Validate job_id is a UUID
    try:
        uuid.UUID(job_id)
    except ValueError:
        return jsonify({'error': 'Invalid job ID'}), 400

    if job_id not in processing_jobs:
        return jsonify({'error': 'Job not found'}), 404

    job = processing_jobs[job_id]
    response = {
        'status': job['status'],
        'filename': job.get('filename'),
        'progress': job.get('progress', ''),
        'created_at': job.get('created_at')
    }

    # Include error message if job failed
    if job['status'] == 'failed' and 'error' in job:
        response['error'] = job['error']

    return jsonify(response)

@app.route('/download/<job_id>')
def download_file(job_id):
    """Download completed PDF"""
    # Validate job_id is a UUID
    try:
        uuid.UUID(job_id)
    except ValueError:
        return jsonify({'error': 'Invalid job ID'}), 400

    if job_id not in processing_jobs:
        return jsonify({'error': 'Job not found'}), 404

    job = processing_jobs[job_id]

    if job['status'] != 'completed':
        return jsonify({'error': f"Job status: {job['status']}"}), 400

    output_path = job['output_path']

    # Security: verify the path is still within UPLOAD_FOLDER
    if not os.path.abspath(output_path).startswith(os.path.abspath(app.config['UPLOAD_FOLDER'])):
        return jsonify({'error': 'Invalid file path'}), 403

    if not os.path.exists(output_path):
        return jsonify({'error': 'File not found'}), 404

    return send_file(
        output_path,
        as_attachment=True,
        download_name=job['filename'],
        mimetype='application/pdf'
    )

if __name__ == '__main__':
    app.run(debug=False, port=5000)
