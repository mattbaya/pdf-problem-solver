<?php
// PDF Font Fixer - PHP Version
// This can be run on any PHP-enabled web server without a dedicated process

// Configuration
define('MAX_FILE_SIZE', 100 * 1024 * 1024); // 100MB
define('UPLOAD_DIR', sys_get_temp_dir() . '/pdf-fixer/');
define('SCRIPT_PATH', dirname(__DIR__) . '/fix-pdf-fonts-interactive.sh');
define('CLEANUP_AGE', 86400); // Clean files older than 24 hours

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

    // Handle logo upload if present
    $logo_path = null;
    if (isset($_FILES['cover_logo']) && $_FILES['cover_logo']['error'] === UPLOAD_ERR_OK) {
        $logo = $_FILES['cover_logo'];
        $logo_ext = strtolower(pathinfo($logo['name'], PATHINFO_EXTENSION));

        if (in_array($logo_ext, ['png', 'jpg', 'jpeg', 'pdf'])) {
            $logo_path = UPLOAD_DIR . $upload_id . '_logo.' . $logo_ext;
            move_uploaded_file($logo['tmp_name'], $logo_path);
        }
    }

    echo json_encode([
        'success' => true,
        'upload_id' => $upload_id,
        'filename' => $filename,
        'has_logo' => $logo_path !== null
    ]);
}

function handle_process() {
    if (!isset($_POST['upload_id']) || !isset($_POST['filename'])) {
        echo json_encode(['error' => 'Missing parameters']);
        return;
    }

    $upload_id = $_POST['upload_id'];
    $filename = $_POST['filename'];
    $email = $_POST['email'] ?? '';
    $pages_mode = $_POST['pages'] ?? 'all';
    $custom_pages = $_POST['custom_pages'] ?? '';
    $dpi = $_POST['dpi'] ?? '600';

    // Get processing options
    $do_ocr = ($_POST['ocr'] ?? '0') === '1';
    $add_page_numbers = ($_POST['page_numbers'] ?? '0') === '1';
    $compress = ($_POST['compress'] ?? '0') === '1';
    $remove_security = ($_POST['remove_security'] ?? '0') === '1';
    $generate_toc = ($_POST['generate_toc'] ?? '0') === '1';
    $generate_cover = ($_POST['generate_cover'] ?? '0') === '1';

    // Get cover sheet details if requested
    $cover_title = $_POST['cover_title'] ?? '';
    $cover_author = $_POST['cover_author'] ?? '';
    $cover_subtitle = $_POST['cover_subtitle'] ?? '';
    $cover_date = $_POST['cover_date'] ?? '';
    $cover_contact = $_POST['cover_contact'] ?? '';

    // Validate inputs
    if (!preg_match('/^pdf_[a-z0-9.]+$/i', $upload_id)) {
        echo json_encode(['error' => 'Invalid upload ID']);
        return;
    }

    // Validate DPI
    if (!in_array($dpi, ['300', '600', '1200'])) {
        $dpi = '600';
    }

    $input_path = UPLOAD_DIR . $upload_id . '_input_' . $filename;
    $current_file = $input_path;

    if (!file_exists($input_path)) {
        echo json_encode(['error' => 'Input file not found']);
        return;
    }

    // Check if script exists
    if (!file_exists(SCRIPT_PATH)) {
        echo json_encode(['error' => 'Processing script not found at: ' . SCRIPT_PATH]);
        return;
    }

    // Step 1: Remove security if requested (must be first)
    if ($remove_security) {
        $unlock_script = dirname(SCRIPT_PATH) . '/additional-tools/unlock-pdf.sh';
        if (file_exists($unlock_script)) {
            $command = escapeshellarg($unlock_script) . ' ' . escapeshellarg($current_file) . ' 2>&1';
            exec($command, $output, $return_code);

            // Look for unlocked file
            $expected_unlocked = str_replace('.pdf', '-unlocked.pdf', $current_file);
            if (file_exists($expected_unlocked)) {
                if ($current_file !== $input_path) {
                    unlink($current_file);
                }
                $current_file = $expected_unlocked;
            }
        }
    }

    // Step 2: Fix PDF fonts (main processing)
    $command = escapeshellarg(SCRIPT_PATH) . ' ' . escapeshellarg($current_file);
    $command .= ' --dpi ' . escapeshellarg($dpi);

    // Add page selection
    if ($pages_mode === 'custom' && !empty($custom_pages)) {
        $pages = str_replace(',', ' ', $custom_pages);
        $command .= ' --pages ' . escapeshellarg($pages);
    } else {
        $command .= ' --pages ' . escapeshellarg($pages_mode);
    }

    // Add auto-confirmation
    $temp_output = UPLOAD_DIR . $upload_id . '_temp_fixed.pdf';
    $command = sprintf(
        'echo -e "y\n%s\ny\n" | %s 2>&1',
        $temp_output,  // Don't escapeshellarg here - it's already in quotes
        $command
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

    // Find the fixed output
    $auto_output = str_replace('.pdf', '-FIXED.pdf', $current_file);
    if (file_exists($auto_output)) {
        if ($current_file !== $input_path) {
            unlink($current_file);
        }
        $current_file = $auto_output;
    } elseif (file_exists($temp_output)) {
        if ($current_file !== $input_path) {
            unlink($current_file);
        }
        $current_file = $temp_output;
    } else {
        echo json_encode(['error' => 'Output file was not created']);
        return;
    }

    // Step 3: OCR if requested
    if ($do_ocr) {
        $ocr_script = dirname(SCRIPT_PATH) . '/additional-tools/ocr-and-index.sh';
        if (file_exists($ocr_script)) {
            $command = escapeshellarg($ocr_script) . ' ' . escapeshellarg($current_file) . ' --full-ocr 2>&1';
            exec($command, $output, $return_code);

            // Look for OCR output
            $expected_ocr = str_replace('.pdf', '-OCR.pdf', $current_file);
            if (file_exists($expected_ocr)) {
                unlink($current_file);
                $current_file = $expected_ocr;
            }
        }
    }

    // Step 3b: Generate Table of Contents if requested
    if ($generate_toc) {
        $toc_script = dirname(SCRIPT_PATH) . '/additional-tools/generate-toc.sh';
        if (file_exists($toc_script)) {
            $toc_output = UPLOAD_DIR . $upload_id . '_TOC.pdf';
            $command = escapeshellarg($toc_script) . ' ' . escapeshellarg($current_file) . ' --output ' . escapeshellarg($toc_output) . ' 2>&1';
            exec($command, $output, $return_code);

            // Check if TOC was generated
            if (file_exists($toc_output)) {
                // Prepend TOC to the document
                $temp_combined = UPLOAD_DIR . $upload_id . '_temp_combined.pdf';
                $pdftk_command = 'pdftk ' . escapeshellarg($toc_output) . ' ' . escapeshellarg($current_file) . ' cat output ' . escapeshellarg($temp_combined) . ' 2>&1';
                exec($pdftk_command, $output, $return_code);

                if (file_exists($temp_combined)) {
                    unlink($current_file);
                    $current_file = $temp_combined;
                    // Keep standalone TOC file as well for download
                }
            }
        }
    }

    // Step 4: Add page numbers if requested
    if ($add_page_numbers) {
        $pagenums_script = dirname(SCRIPT_PATH) . '/additional-tools/add-page-numbers.sh';
        if (file_exists($pagenums_script)) {
            $command = escapeshellarg($pagenums_script) . ' ' . escapeshellarg($current_file) . ' 2>&1';
            exec($command, $output, $return_code);

            // Look for numbered output
            $expected_numbered = str_replace('.pdf', '-numbered.pdf', $current_file);
            if (file_exists($expected_numbered)) {
                unlink($current_file);
                $current_file = $expected_numbered;
            }
        }
    }

    // Step 5: Compress if requested (should be last)
    if ($compress) {
        $compress_script = dirname(SCRIPT_PATH) . '/additional-tools/compress-pdf.sh';
        if (file_exists($compress_script)) {
            $command = escapeshellarg($compress_script) . ' ' . escapeshellarg($current_file) . ' ebook 2>&1';
            exec($command, $output, $return_code);

            // Look for compressed output
            $expected_compressed = str_replace('.pdf', '-compressed.pdf', $current_file);
            if (file_exists($expected_compressed)) {
                unlink($current_file);
                $current_file = $expected_compressed;
            }
        }
    }

    // Step 6: Generate cover sheet if requested (must be last, gets prepended)
    if ($generate_cover) {
        $cover_script = dirname(SCRIPT_PATH) . '/additional-tools/generate-cover-sheet.sh';
        if (file_exists($cover_script)) {
            $cover_output = UPLOAD_DIR . $upload_id . '_COVER.pdf';

            // Build command with all cover sheet options
            $command = escapeshellarg($cover_script) . ' --output ' . escapeshellarg($cover_output);
            $command .= ' --source-pdf ' . escapeshellarg($current_file);

            if (!empty($cover_title)) {
                $command .= ' --title ' . escapeshellarg($cover_title);
            }
            if (!empty($cover_author)) {
                $command .= ' --author ' . escapeshellarg($cover_author);
            }
            if (!empty($cover_subtitle)) {
                $command .= ' --subtitle ' . escapeshellarg($cover_subtitle);
            }
            if (!empty($cover_date)) {
                $command .= ' --date ' . escapeshellarg($cover_date);
            }
            if (!empty($cover_contact)) {
                $command .= ' --contact ' . escapeshellarg($cover_contact);
            }

            // Check for logo file
            $logo_files = glob(UPLOAD_DIR . $upload_id . '_logo.*');
            if (!empty($logo_files)) {
                $command .= ' --logo ' . escapeshellarg($logo_files[0]);
            }

            $command .= ' 2>&1';
            exec($command, $output, $return_code);

            // Prepend cover to document
            if (file_exists($cover_output)) {
                $temp_combined = UPLOAD_DIR . $upload_id . '_temp_with_cover.pdf';
                $pdftk_command = 'pdftk ' . escapeshellarg($cover_output) . ' ' . escapeshellarg($current_file) . ' cat output ' . escapeshellarg($temp_combined) . ' 2>&1';
                exec($pdftk_command, $output, $return_code);

                if (file_exists($temp_combined)) {
                    unlink($current_file);
                    $current_file = $temp_combined;
                    // Keep standalone cover for download
                }
            }
        }
    }

    // Final output path
    $output_path = UPLOAD_DIR . $upload_id . '_output_' . $filename;
    rename($current_file, $output_path);

    // Clean up input file
    if (file_exists($input_path)) {
        unlink($input_path);
    }

    $response = [
        'success' => true,
        'download_url' => '?download=1&file=' . urlencode($upload_id . '_output_' . $filename)
    ];

    // Add TOC file URL if it exists
    if ($generate_toc && file_exists(UPLOAD_DIR . $upload_id . '_TOC.pdf')) {
        $response['toc_url'] = '?download=1&file=' . urlencode($upload_id . '_TOC.pdf');
    }

    // Add cover file URL if it exists
    if ($generate_cover && file_exists(UPLOAD_DIR . $upload_id . '_COVER.pdf')) {
        $response['cover_url'] = '?download=1&file=' . urlencode($upload_id . '_COVER.pdf');
    }

    echo json_encode($response);
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
    <title>PDF Problem Solver</title>
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
        
        .form-group {
            margin-bottom: 1.5rem;
        }

        .form-group label {
            display: block;
            margin-bottom: 0.5rem;
            font-weight: 600;
            color: #2c3e50;
        }

        input[type="email"],
        input[type="text"],
        input[type="file"],
        select {
            width: 100%;
            padding: 0.75rem;
            border: 2px solid #ddd;
            border-radius: 5px;
            font-size: 1rem;
            transition: border-color 0.3s ease;
        }

        input[type="email"]:focus,
        input[type="text"]:focus,
        input[type="file"]:focus,
        select:focus {
            outline: none;
            border-color: #3498db;
        }

        select {
            cursor: pointer;
            background-color: white;
        }

        small {
            font-size: 0.875rem;
        }

        input[type="file"] {
            padding: 0.5rem;
        }

        .btn-submit {
            width: 100%;
            padding: 1rem 1.5rem;
            font-size: 1.1rem;
            font-weight: 600;
        }

        .options-grid {
            display: grid;
            gap: 1rem;
            margin-top: 0.5rem;
        }

        .checkbox-label {
            display: flex;
            align-items: flex-start;
            padding: 1rem;
            background-color: #f8f9fa;
            border: 2px solid #e9ecef;
            border-radius: 5px;
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .checkbox-label:hover {
            background-color: #e9ecef;
            border-color: #3498db;
        }

        .checkbox-label input[type="checkbox"] {
            margin-right: 0.75rem;
            margin-top: 0.25rem;
            width: 18px;
            height: 18px;
            cursor: pointer;
            flex-shrink: 0;
        }

        .checkbox-label > div {
            flex: 1;
        }

        .checkbox-label span {
            font-weight: 600;
            color: #2c3e50;
            display: block;
        }

        .checkbox-label small {
            display: block;
            color: #7f8c8d;
            font-size: 0.875rem;
            margin-top: 0.25rem;
        }

        .checkbox-label input[type="checkbox"]:checked ~ div span {
            color: #3498db;
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
            <h1>PDF Problem Solver</h1>
            <p class="subtitle">Fix PDF printing problems where symbols appear instead of text</p>
        </header>
        
        <div class="upload-section">
            <form id="uploadForm">
                <div class="form-group">
                    <label for="emailInput">Your Email (optional, for notification when processing is complete):</label>
                    <input type="email" id="emailInput" name="email" placeholder="your.email@example.com">
                </div>

                <div class="form-group">
                    <label for="fileInput">Select PDF File:</label>
                    <input type="file" id="fileInput" name="file" accept=".pdf" required>
                </div>

                <div class="form-group">
                    <label for="pageSelection">Pages to Convert:</label>
                    <select id="pageSelection" name="pages">
                        <option value="all">Convert all pages (safest, recommended)</option>
                        <option value="auto">Auto-detect problem pages only</option>
                        <option value="custom">Specific pages (enter below)</option>
                    </select>
                </div>

                <div class="form-group" id="customPagesGroup" style="display: none;">
                    <label for="customPages">Page Numbers (comma or space separated, e.g., "1,3,5" or "1 3 5"):</label>
                    <input type="text" id="customPages" name="custom_pages" placeholder="e.g., 1, 3, 5-10, 15">
                </div>

                <div class="form-group">
                    <label for="dpiSelection">Image Quality (DPI):</label>
                    <select id="dpiSelection" name="dpi">
                        <option value="300">300 DPI (Good, faster)</option>
                        <option value="600" selected>600 DPI (Excellent, recommended for printing)</option>
                        <option value="1200">1200 DPI (Maximum quality, slower)</option>
                    </select>
                    <small style="color: #7f8c8d; display: block; margin-top: 0.5rem;">
                        Higher DPI = better print quality but larger file size
                    </small>
                </div>

                <div class="form-group">
                    <label>Additional Processing Options:</label>
                    <div class="options-grid">
                        <label class="checkbox-label">
                            <input type="checkbox" name="ocr" id="ocrCheck" value="1">
                            <div>
                                <span>Re-OCR Document</span>
                                <small>Extract text using OCR (useful for scanned documents)</small>
                            </div>
                        </label>

                        <label class="checkbox-label">
                            <input type="checkbox" name="page_numbers" id="pageNumbersCheck" value="1">
                            <div>
                                <span>Add Page Numbers</span>
                                <small>Add page numbers to each page</small>
                            </div>
                        </label>

                        <label class="checkbox-label">
                            <input type="checkbox" name="compress" id="compressCheck" value="1">
                            <div>
                                <span>Compress Output</span>
                                <small>Reduce file size while maintaining quality</small>
                            </div>
                        </label>

                        <label class="checkbox-label">
                            <input type="checkbox" name="remove_security" id="removeSecurityCheck" value="1">
                            <div>
                                <span>Remove Security</span>
                                <small>Remove password protection or restrictions</small>
                            </div>
                        </label>

                        <label class="checkbox-label">
                            <input type="checkbox" name="generate_toc" id="generateTocCheck" value="1">
                            <div>
                                <span>Generate Table of Contents</span>
                                <small>Create a printable TOC page listing all headlines with page numbers</small>
                            </div>
                        </label>

                        <label class="checkbox-label">
                            <input type="checkbox" name="generate_cover" id="generateCoverCheck" value="1">
                            <div>
                                <span>Generate Cover Sheet</span>
                                <small>Create a professional cover page for your document</small>
                            </div>
                        </label>
                    </div>
                </div>

                <!-- Cover Sheet Options (hidden by default) -->
                <div class="form-group" id="coverSheetOptions" style="display: none;">
                    <label style="font-size: 1.1rem; margin-bottom: 1rem; display: block;">Cover Sheet Details:</label>

                    <div style="background: #f8f9fa; padding: 1.5rem; border-radius: 8px; margin-bottom: 1rem;">
                        <div style="margin-bottom: 1rem;">
                            <label for="coverTitle">Title:</label>
                            <input type="text" id="coverTitle" name="cover_title" placeholder="Will be auto-filled from PDF">
                        </div>

                        <div style="margin-bottom: 1rem;">
                            <label for="coverAuthor">Author Name:</label>
                            <input type="text" id="coverAuthor" name="cover_author" placeholder="e.g., Prof. Jane Smith">
                        </div>

                        <div style="margin-bottom: 1rem;">
                            <label for="coverSubtitle">Subtitle (optional):</label>
                            <input type="text" id="coverSubtitle" name="cover_subtitle" placeholder="e.g., Course Readings for Fall 2025">
                        </div>

                        <div style="margin-bottom: 1rem;">
                            <label for="coverDate">Date:</label>
                            <input type="text" id="coverDate" name="cover_date" placeholder="Will be auto-filled with current date">
                        </div>

                        <div style="margin-bottom: 1rem;">
                            <label for="coverContact">Contact Information (optional):</label>
                            <input type="text" id="coverContact" name="cover_contact" placeholder="e.g., jsmith@institution.edu">
                        </div>

                        <div style="margin-bottom: 0;">
                            <label for="coverLogo">Logo (optional - PNG, JPG, or PDF):</label>
                            <input type="file" id="coverLogo" name="cover_logo" accept=".png,.jpg,.jpeg,.pdf">
                            <small style="display: block; margin-top: 0.5rem; color: #666;">Logo will appear in the top 1/4 of the cover page</small>
                        </div>
                    </div>
                </div>

                <div class="form-group">
                    <button type="submit" class="btn btn-submit" id="submitBtn">
                        Fix PDF
                    </button>
                </div>
            </form>

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
        const uploadForm = document.getElementById('uploadForm');
        const fileInput = document.getElementById('fileInput');
        const emailInput = document.getElementById('emailInput');
        const pageSelection = document.getElementById('pageSelection');
        const customPagesGroup = document.getElementById('customPagesGroup');
        const customPages = document.getElementById('customPages');
        const dpiSelection = document.getElementById('dpiSelection');
        const submitBtn = document.getElementById('submitBtn');
        const fileInfo = document.getElementById('fileInfo');
        const fileName = document.getElementById('fileName');
        const fileSize = document.getElementById('fileSize');
        const processing = document.getElementById('processing');
        const processingMessage = document.getElementById('processingMessage');
        const result = document.getElementById('result');
        const error = document.getElementById('error');
        const errorMessage = document.getElementById('errorMessage');
        const downloadBtn = document.getElementById('downloadBtn');
        const generateCoverCheck = document.getElementById('generateCoverCheck');
        const coverSheetOptions = document.getElementById('coverSheetOptions');
        const coverTitle = document.getElementById('coverTitle');

        let currentUploadId = null;

        // Show/hide custom pages input
        pageSelection.addEventListener('change', (e) => {
            if (e.target.value === 'custom') {
                customPagesGroup.style.display = 'block';
                customPages.required = true;
            } else {
                customPagesGroup.style.display = 'none';
                customPages.required = false;
            }
        });

        // Show/hide cover sheet options
        generateCoverCheck.addEventListener('change', (e) => {
            if (e.target.checked) {
                coverSheetOptions.style.display = 'block';
                // Auto-fill title from filename if available
                if (fileInput.files.length > 0 && !coverTitle.value) {
                    const filename = fileInput.files[0].name.replace('.pdf', '').replace(/_/g, ' ');
                    coverTitle.placeholder = filename;
                }
            } else {
                coverSheetOptions.style.display = 'none';
            }
        });

        // File input change - show file info
        fileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                const file = e.target.files[0];
                fileName.textContent = file.name;
                fileSize.textContent = formatFileSize(file.size);
                fileInfo.style.display = 'block';
            } else {
                fileInfo.style.display = 'none';
            }
        });

        // Form submission
        uploadForm.addEventListener('submit', (e) => {
            e.preventDefault();

            if (fileInput.files.length === 0) {
                showError('Please select a PDF file.');
                return;
            }

            if (pageSelection.value === 'custom' && !customPages.value.trim()) {
                showError('Please enter page numbers or select a different option.');
                return;
            }

            handleFile(fileInput.files[0]);
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
            formData.append('email', emailInput.value);
            formData.append('pages', pageSelection.value);
            formData.append('custom_pages', customPages.value);
            formData.append('dpi', dpiSelection.value);
            formData.append('ocr', document.getElementById('ocrCheck').checked ? '1' : '0');
            formData.append('page_numbers', document.getElementById('pageNumbersCheck').checked ? '1' : '0');
            formData.append('compress', document.getElementById('compressCheck').checked ? '1' : '0');
            formData.append('remove_security', document.getElementById('removeSecurityCheck').checked ? '1' : '0');
            formData.append('generate_toc', document.getElementById('generateTocCheck').checked ? '1' : '0');
            formData.append('generate_cover', document.getElementById('generateCoverCheck').checked ? '1' : '0');

            // Add cover sheet details if cover is requested
            if (document.getElementById('generateCoverCheck').checked) {
                formData.append('cover_title', document.getElementById('coverTitle').value);
                formData.append('cover_author', document.getElementById('coverAuthor').value);
                formData.append('cover_subtitle', document.getElementById('coverSubtitle').value);
                formData.append('cover_date', document.getElementById('coverDate').value);
                formData.append('cover_contact', document.getElementById('coverContact').value);
            }

            fetch('index.php', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                processing.style.display = 'none';

                if (data.success) {
                    showSuccess(data.download_url, data.toc_url, data.cover_url);
                } else {
                    showError(data.error || 'Processing failed', data.details);
                }
            })
            .catch(err => {
                processing.style.display = 'none';
                showError('An error occurred while processing the file.');
            });
        }
        
        function showSuccess(downloadUrl, tocUrl, coverUrl) {
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

            // Clear any existing extra download links
            const existingLinks = document.getElementById('extraDownloadLinks');
            if (existingLinks) {
                existingLinks.remove();
            }

            // Create container for extra downloads
            if (tocUrl || coverUrl) {
                const extraLinksContainer = document.createElement('div');
                extraLinksContainer.id = 'extraDownloadLinks';
                extraLinksContainer.style.marginTop = '20px';
                extraLinksContainer.style.paddingTop = '20px';
                extraLinksContainer.style.borderTop = '1px solid #ddd';

                let linksHTML = '<p style="margin-bottom: 15px; font-weight: 600; color: #2c3e50;">Additional Files:</p>';

                if (coverUrl) {
                    linksHTML += `
                        <div style="margin-bottom: 10px;">
                            <a href="${coverUrl}" class="btn" style="background-color: #9b59b6;">
                                📄 Download Cover Sheet (standalone)
                            </a>
                        </div>
                    `;
                }

                if (tocUrl) {
                    linksHTML += `
                        <div style="margin-bottom: 10px;">
                            <a href="${tocUrl}" class="btn" style="background-color: #27ae60;">
                                📋 Download Table of Contents (standalone)
                            </a>
                        </div>
                    `;
                }

                linksHTML += '<p style="margin-top: 15px; color: #666; font-size: 14px;">Note: Cover and TOC are already included in the main PDF above.</p>';

                extraLinksContainer.innerHTML = linksHTML;
                downloadBtn.parentNode.appendChild(extraLinksContainer);
            }
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