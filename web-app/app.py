from flask import Flask, request, render_template, send_file, jsonify
import os
import subprocess
import tempfile
import shutil
from werkzeug.utils import secure_filename
import uuid

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB max file size
app.config['UPLOAD_FOLDER'] = tempfile.mkdtemp()

ALLOWED_EXTENSIONS = {'pdf'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/')
def index():
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
        
        # Process the PDF
        try:
            output_filename = f"fixed_{filename}"
            output_path = os.path.join(app.config['UPLOAD_FOLDER'], f"{unique_id}_{output_filename}")
            
            # Call the shell script with automatic mode
            script_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                                     'fix-pdf-fonts-interactive.sh')
            
            # Run the script with input redirected to select option 1 (Fix all pages)
            process = subprocess.Popen(
                [script_path, input_path, output_path],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Send "1" to select "Fix all pages" option
            stdout, stderr = process.communicate(input='1\n')
            
            if process.returncode != 0:
                # Clean up input file
                os.remove(input_path)
                return jsonify({'error': f'PDF processing failed: {stderr}'}), 500
            
            # Check if output file was created
            if not os.path.exists(output_path):
                os.remove(input_path)
                return jsonify({'error': 'Output file was not created'}), 500
            
            # Store the file paths for download
            return jsonify({
                'success': True,
                'download_id': unique_id,
                'filename': output_filename
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
    
    # Run the app
    app.run(debug=True, port=5000)