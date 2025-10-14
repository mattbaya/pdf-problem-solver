<?php
// PDF Font Fixer - PHP Version
// This can be run on any PHP-enabled web server without a dedicated process

// Configuration
define('MAX_FILE_SIZE', 100 * 1024 * 1024); // 100MB
define('UPLOAD_DIR', sys_get_temp_dir() . '/pdf-fixer/');
define('SCRIPT_PATH', dirname(__DIR__) . '/fix-pdf-fonts-interactive.sh');
define('CLEANUP_AGE', 3600); // Clean files older than 1 hour

// Ensure upload directory exists
if (!file_exists(UPLOAD_DIR)) {
    mkdir(UPLOAD_DIR, 0777, true);
}

// Clean old files on each request
cleanup_old_files();

function cleanup_old_files() {
    if (!is_dir(UPLOAD_DIR)) return;
    
    $files = glob(UPLOAD_DIR . '*');
    $now = time();
    
    foreach ($files as $file) {
        if (is_file($file) && ($now - filemtime($file)) > CLEANUP_AGE) {
            unlink($file);
        }
    }
}

// Handle AJAX requests
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    header('Content-Type: application/json');
    
    switch ($_POST['action']) {
        case 'upload':
            handle_upload();
            break;
        case 'process':
            handle_process();
            break;
        case 'cleanup':
            handle_cleanup();
            break;
        default:
            echo json_encode(['error' => 'Invalid action']);
    }
    exit;
}

// Handle file download
if (isset($_GET['download']) && isset($_GET['file'])) {
    handle_download();
    exit;
}

function handle_upload() {
    if (!isset($_FILES['file'])) {
        echo json_encode(['error' => 'No file provided']);
        return;
    }
    
    $file = $_FILES['file'];
    
    if ($file['error'] !== UPLOAD_ERR_OK) {
        echo json_encode(['error' => 'Upload failed']);
        return;
    }
    
    if ($file['size'] > MAX_FILE_SIZE) {
        echo json_encode(['error' => 'File too large. Maximum size is 100MB']);
        return;
    }
    
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mime_type = finfo_file($finfo, $file['tmp_name']);
    finfo_close($finfo);
    
    if ($mime_type !== 'application/pdf') {
        echo json_encode(['error' => 'Only PDF files are allowed']);
        return;
    }
    
    // Generate unique ID and save file
    $upload_id = uniqid('pdf_', true);
    $filename = basename($file['name']);
    $input_path = UPLOAD_DIR . $upload_id . '_input_' . $filename;
    
    if (!move_uploaded_file($file['tmp_name'], $input_path)) {
        echo json_encode(['error' => 'Failed to save file']);
        return;
    }
    
    echo json_encode([
        'success' => true,
        'upload_id' => $upload_id,
        'filename' => $filename
    ]);
}

function handle_process() {
    if (!isset($_POST['upload_id']) || !isset($_POST['filename'])) {
        echo json_encode(['error' => 'Missing parameters']);
        return;
    }
    
    $upload_id = $_POST['upload_id'];
    $filename = $_POST['filename'];
    
    // Validate inputs
    if (!preg_match('/^pdf_[a-z0-9.]+$/i', $upload_id)) {
        echo json_encode(['error' => 'Invalid upload ID']);
        return;
    }
    
    $input_path = UPLOAD_DIR . $upload_id . '_input_' . $filename;
    $output_path = UPLOAD_DIR . $upload_id . '_output_' . $filename;
    
    if (!file_exists($input_path)) {
        echo json_encode(['error' => 'Input file not found']);
        return;
    }
    
    // Check if script exists
    if (!file_exists(SCRIPT_PATH)) {
        echo json_encode(['error' => 'Processing script not found at: ' . SCRIPT_PATH]);
        return;
    }
    
    // Run the shell script
    $command = sprintf(
        'echo "1" | %s %s %s 2>&1',
        escapeshellarg(SCRIPT_PATH),
        escapeshellarg($input_path),
        escapeshellarg($output_path)
    );
    
    $output = [];
    $return_code = 0;
    exec($command, $output, $return_code);
    
    if ($return_code !== 0) {
        echo json_encode([
            'error' => 'PDF processing failed',
            'details' => implode("\n", $output)
        ]);
        return;
    }
    
    if (!file_exists($output_path)) {
        echo json_encode(['error' => 'Output file was not created']);
        return;
    }
    
    echo json_encode([
        'success' => true,
        'download_url' => '?download=1&file=' . urlencode($upload_id . '_output_' . $filename)
    ]);
}

function handle_download() {
    $file = $_GET['file'];
    
    // Validate filename format
    if (!preg_match('/^pdf_[a-z0-9._]+$/i', $file)) {
        header('HTTP/1.0 400 Bad Request');
        echo 'Invalid file';
        return;
    }
    
    $file_path = UPLOAD_DIR . $file;
    
    if (!file_exists($file_path)) {
        header('HTTP/1.0 404 Not Found');
        echo 'File not found';
        return;
    }
    
    // Extract original filename
    $parts = explode('_output_', $file, 2);
    $download_name = isset($parts[1]) ? 'fixed_' . $parts[1] : 'fixed_document.pdf';
    
    header('Content-Type: application/pdf');
    header('Content-Disposition: attachment; filename="' . $download_name . '"');
    header('Content-Length: ' . filesize($file_path));
    header('Cache-Control: no-cache, must-revalidate');
    
    readfile($file_path);
}

function handle_cleanup() {
    if (!isset($_POST['upload_id'])) {
        echo json_encode(['error' => 'Missing upload ID']);
        return;
    }
    
    $upload_id = $_POST['upload_id'];
    
    // Remove all files with this upload ID
    $files = glob(UPLOAD_DIR . $upload_id . '_*');
    foreach ($files as $file) {
        if (is_file($file)) {
            unlink($file);
        }
    }
    
    echo json_encode(['success' => true]);
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PDF Font Fixer</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            background-color: #f5f5f5;
            color: #333;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 2rem;
        }
        
        header {
            text-align: center;
            margin-bottom: 3rem;
        }
        
        h1 {
            font-size: 2.5rem;
            color: #2c3e50;
            margin-bottom: 0.5rem;
        }
        
        .subtitle {
            color: #7f8c8d;
            font-size: 1.1rem;
        }
        
        .upload-section {
            background: white;
            padding: 2rem;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            margin-bottom: 2rem;
        }
        
        .upload-area {
            border: 3px dashed #3498db;
            border-radius: 8px;
            padding: 3rem;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s ease;
            background-color: #f8f9fa;
        }
        
        .upload-area:hover {
            background-color: #e3f2fd;
            border-color: #2196f3;
        }
        
        .upload-area.drag-over {
            background-color: #e3f2fd;
            border-color: #2196f3;
            transform: scale(1.02);
        }
        
        .upload-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        
        input[type="file"] {
            display: none;
        }
        
        .btn {
            display: inline-block;
            padding: 0.75rem 1.5rem;
            background-color: #3498db;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            border: none;
            cursor: pointer;
            font-size: 1rem;
            transition: background-color 0.3s ease;
        }
        
        .btn:hover {
            background-color: #2980b9;
        }
        
        .btn:disabled {
            background-color: #95a5a6;
            cursor: not-allowed;
        }
        
        .btn-success {
            background-color: #27ae60;
        }
        
        .btn-success:hover {
            background-color: #229954;
        }
        
        .file-info {
            margin-top: 1rem;
            padding: 1rem;
            background-color: #ecf0f1;
            border-radius: 5px;
            display: none;
        }
        
        .processing {
            display: none;
            text-align: center;
            margin-top: 2rem;
        }
        
        .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 1rem;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .result {
            display: none;
            text-align: center;
            margin-top: 2rem;
            padding: 2rem;
            background-color: #d4edda;
            border-radius: 8px;
            border: 1px solid #c3e6cb;
        }
        
        .error {
            display: none;
            text-align: center;
            margin-top: 2rem;
            padding: 2rem;
            background-color: #f8d7da;
            border-radius: 8px;
            border: 1px solid #f5c6cb;
            color: #721c24;
        }
        
        .features {
            background: white;
            padding: 2rem;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }
        
        .features h2 {
            color: #2c3e50;
            margin-bottom: 1rem;
        }
        
        .features ul {
            list-style: none;
            padding-left: 0;
        }
        
        .features li {
            padding: 0.5rem 0;
            padding-left: 1.5rem;
            position: relative;
        }
        
        .features li:before {
            content: "✓";
            color: #27ae60;
            font-weight: bold;
            position: absolute;
            left: 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>PDF Font Fixer</h1>
            <p class="subtitle">Fix PDF printing problems where symbols appear instead of text</p>
        </header>
        
        <div class="upload-section">
            <div class="upload-area" id="uploadArea">
                <div class="upload-icon">📄</div>
                <p><strong>Drop your PDF file here</strong></p>
                <p>or</p>
                <button class="btn" onclick="document.getElementById('fileInput').click()">
                    Choose File
                </button>
                <input type="file" id="fileInput" accept=".pdf">
            </div>
            
            <div class="file-info" id="fileInfo">
                <strong>Selected file:</strong> <span id="fileName"></span>
                <br>
                <strong>Size:</strong> <span id="fileSize"></span>
            </div>
            
            <div class="processing" id="processing">
                <div class="spinner"></div>
                <p id="processingMessage">Uploading your PDF...</p>
            </div>
            
            <div class="result" id="result">
                <h3>✅ Success!</h3>
                <p>Your PDF has been fixed. All pages have been converted to high-resolution images to ensure proper printing.</p>
                <br>
                <a href="#" class="btn btn-success" id="downloadBtn">Download Fixed PDF</a>
            </div>
            
            <div class="error" id="error">
                <h3>❌ Error</h3>
                <p id="errorMessage"></p>
            </div>
        </div>
        
        <div class="features">
            <h2>What this tool does:</h2>
            <ul>
                <li>Fixes PDFs that show symbols (✦, ⌘, ☃) instead of text when printing</li>
                <li>Converts all pages to high-resolution (300 DPI) images</li>
                <li>Preserves document quality for professional printing</li>
                <li>Automatically handles font encoding issues</li>
                <li>Maintains original page layout and formatting</li>
            </ul>
        </div>
    </div>
    
    <script>
        const uploadArea = document.getElementById('uploadArea');
        const fileInput = document.getElementById('fileInput');
        const fileInfo = document.getElementById('fileInfo');
        const fileName = document.getElementById('fileName');
        const fileSize = document.getElementById('fileSize');
        const processing = document.getElementById('processing');
        const processingMessage = document.getElementById('processingMessage');
        const result = document.getElementById('result');
        const error = document.getElementById('error');
        const errorMessage = document.getElementById('errorMessage');
        const downloadBtn = document.getElementById('downloadBtn');
        
        let currentUploadId = null;
        
        // Drag and drop functionality
        uploadArea.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadArea.classList.add('drag-over');
        });
        
        uploadArea.addEventListener('dragleave', () => {
            uploadArea.classList.remove('drag-over');
        });
        
        uploadArea.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadArea.classList.remove('drag-over');
            
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                handleFile(files[0]);
            }
        });
        
        // File input change
        fileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                handleFile(e.target.files[0]);
            }
        });
        
        function formatFileSize(bytes) {
            if (bytes === 0) return '0 Bytes';
            const k = 1024;
            const sizes = ['Bytes', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }
        
        function handleFile(file) {
            if (file.type !== 'application/pdf') {
                showError('Please select a PDF file.');
                return;
            }
            
            if (file.size > 100 * 1024 * 1024) {
                showError('File size must be less than 100MB.');
                return;
            }
            
            // Show file info
            fileName.textContent = file.name;
            fileSize.textContent = formatFileSize(file.size);
            fileInfo.style.display = 'block';
            
            // Upload file
            uploadFile(file);
        }
        
        function uploadFile(file) {
            const formData = new FormData();
            formData.append('file', file);
            formData.append('action', 'upload');
            
            // Hide previous results
            result.style.display = 'none';
            error.style.display = 'none';
            processing.style.display = 'block';
            processingMessage.textContent = 'Uploading your PDF...';
            
            fetch('index.php', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    currentUploadId = data.upload_id;
                    processFile(data.upload_id, data.filename);
                } else {
                    processing.style.display = 'none';
                    showError(data.error || 'Upload failed');
                }
            })
            .catch(err => {
                processing.style.display = 'none';
                showError('An error occurred while uploading the file.');
            });
        }
        
        function processFile(uploadId, filename) {
            processingMessage.textContent = 'Processing your PDF... This may take a moment.';
            
            const formData = new FormData();
            formData.append('action', 'process');
            formData.append('upload_id', uploadId);
            formData.append('filename', filename);
            
            fetch('index.php', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                processing.style.display = 'none';
                
                if (data.success) {
                    showSuccess(data.download_url);
                } else {
                    showError(data.error || 'Processing failed', data.details);
                }
            })
            .catch(err => {
                processing.style.display = 'none';
                showError('An error occurred while processing the file.');
            });
        }
        
        function showSuccess(downloadUrl) {
            result.style.display = 'block';
            downloadBtn.href = downloadUrl;
            downloadBtn.onclick = () => {
                // Clean up files after download
                if (currentUploadId) {
                    setTimeout(() => {
                        const formData = new FormData();
                        formData.append('action', 'cleanup');
                        formData.append('upload_id', currentUploadId);
                        
                        fetch('index.php', {
                            method: 'POST',
                            body: formData
                        });
                    }, 1000);
                }
            };
        }
        
        function showError(message, details) {
            error.style.display = 'block';
            errorMessage.textContent = message;
            if (details) {
                errorMessage.textContent += '\n\nDetails: ' + details;
            }
        }
    </script>
</body>
</html>