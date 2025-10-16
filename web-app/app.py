from flask import Flask, request, render_template, send_file, jsonify
import os
import subprocess
import tempfile
import shutil
from werkzeug.utils import secure_filename
import uuid
import time

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB max file size
app.config['UPLOAD_FOLDER'] = tempfile.mkdtemp()

ALLOWED_EXTENSIONS = {'pdf'}
CLEANUP_AGE = 86400  # Clean files older than 24 hours (in seconds)

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

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/')
def index():
    cleanup_old_files()  # Run cleanup on each request
    return render_template('index.html')

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400

    if file and allowed_file(file.filename):
        # Generate unique filename to avoid conflicts
        unique_id = str(uuid.uuid4())
        filename = secure_filename(file.filename)
        input_path = os.path.join(app.config['UPLOAD_FOLDER'], f"{unique_id}_{filename}")
        file.save(input_path)

        # Get parameters from form
        email = request.form.get('email', '')
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

        # Process the PDF
        try:
            output_filename = f"fixed_{filename}"
            current_file = input_path

            # Step 1: Remove security if requested (must be first)
            if remove_security:
                unlocked_path = os.path.join(app.config['UPLOAD_FOLDER'], f"{unique_id}_unlocked.pdf")
                unlock_script = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                           'additional-tools', 'unlock-pdf.sh')

                result = subprocess.run(
                    [unlock_script, current_file],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )

                # Look for the unlocked file (script adds -unlocked suffix)
                expected_unlocked = current_file.replace('.pdf', '-unlocked.pdf')
                if os.path.exists(expected_unlocked):
                    if current_file != input_path:
                        os.remove(current_file)
                    current_file = expected_unlocked

            # Step 2: Fix PDF fonts (main processing)
            fixed_path = os.path.join(app.config['UPLOAD_FOLDER'], f"{unique_id}_fixed.pdf")
            script_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                     'fix-pdf-fonts-interactive.sh')

            # Build command with parameters
            cmd = [script_path, current_file, '--dpi', dpi]

            # Add page selection
            if pages_mode == 'custom' and custom_pages:
                pages = custom_pages.replace(',', ' ')
                cmd.extend(['--pages', pages])
            else:
                cmd.extend(['--pages', pages_mode])

            # Run the script with auto-confirmation
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                stdin=subprocess.PIPE,
                text=True
            )

            stdout, stderr = process.communicate(input=f"y\n{fixed_path}\ny\n")

            if process.returncode != 0:
                # Clean up
                if current_file != input_path:
                    os.remove(current_file)
                os.remove(input_path)
                return jsonify({'error': f'PDF processing failed: {stderr}'}), 500

            # Find the output file (script adds -FIXED suffix)
            auto_output = current_file.replace('.pdf', '-FIXED.pdf')
            if os.path.exists(auto_output):
                if current_file != input_path:
                    os.remove(current_file)
                current_file = auto_output
            elif os.path.exists(fixed_path):
                if current_file != input_path:
                    os.remove(current_file)
                current_file = fixed_path
            else:
                if current_file != input_path:
                    os.remove(current_file)
                os.remove(input_path)
                return jsonify({'error': 'Output file was not created'}), 500

            # Step 3: OCR if requested
            if do_ocr:
                ocr_path = os.path.join(app.config['UPLOAD_FOLDER'], f"{unique_id}_ocr.pdf")
                ocr_script = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                        'additional-tools', 'ocr-and-index.sh')

                result = subprocess.run(
                    [ocr_script, current_file, '--full-ocr'],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )

                # Look for OCR output (script adds -OCR suffix)
                expected_ocr = current_file.replace('.pdf', '-OCR.pdf')
                if os.path.exists(expected_ocr):
                    os.remove(current_file)
                    current_file = expected_ocr

            # Step 4: Add page numbers if requested
            if add_page_numbers:
                numbered_path = os.path.join(app.config['UPLOAD_FOLDER'], f"{unique_id}_numbered.pdf")
                pagenums_script = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                             'additional-tools', 'add-page-numbers.sh')

                result = subprocess.run(
                    [pagenums_script, current_file],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )

                # Look for numbered output (script adds -numbered suffix)
                expected_numbered = current_file.replace('.pdf', '-numbered.pdf')
                if os.path.exists(expected_numbered):
                    os.remove(current_file)
                    current_file = expected_numbered

            # Step 5: Compress if requested (should be last)
            if compress:
                compress_script = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                             'additional-tools', 'compress-pdf.sh')

                result = subprocess.run(
                    [compress_script, current_file, 'ebook'],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )

                # Look for compressed output (script adds -compressed suffix)
                expected_compressed = current_file.replace('.pdf', '-compressed.pdf')
                if os.path.exists(expected_compressed):
                    os.remove(current_file)
                    current_file = expected_compressed

            # Final output path
            output_path = os.path.join(app.config['UPLOAD_FOLDER'], f"{unique_id}_{output_filename}")
            shutil.move(current_file, output_path)

            # Clean up input file
            if os.path.exists(input_path):
                os.remove(input_path)

            # Store the file paths for download
            return jsonify({
                'success': True,
                'download_id': unique_id,
                'filename': output_filename,
                'email': email  # Store for future email notification feature
            })

        except Exception as e:
            # Clean up on error
            if os.path.exists(input_path):
                os.remove(input_path)
            return jsonify({'error': str(e)}), 500

    return jsonify({'error': 'Invalid file type. Only PDF files are allowed.'}), 400

@app.route('/download/<download_id>/<filename>')
def download_file(download_id, filename):
    try:
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], f"{download_id}_{filename}")
        if os.path.exists(file_path):
            return send_file(file_path, as_attachment=True, download_name=filename)
        else:
            return jsonify({'error': 'File not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/cleanup', methods=['POST'])
def cleanup():
    """Clean up processed files after download"""
    data = request.get_json()
    download_id = data.get('download_id')
    
    if download_id:
        # Remove all files with this download_id
        for filename in os.listdir(app.config['UPLOAD_FOLDER']):
            if filename.startswith(download_id):
                try:
                    os.remove(os.path.join(app.config['UPLOAD_FOLDER'], filename))
                except:
                    pass
    
    return jsonify({'success': True})

if __name__ == '__main__':
    # Ensure upload directory exists
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

    # Get configuration from environment variables
    host = os.environ.get('FLASK_HOST', '0.0.0.0')  # 0.0.0.0 allows external connections
    port = int(os.environ.get('FLASK_PORT', '5000'))
    debug = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'

    # Run the app
    app.run(host=host, port=port, debug=debug)