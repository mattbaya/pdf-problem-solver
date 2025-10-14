# PDF Font Fixer - PHP Version

A lightweight PHP version of the PDF Font Fixer that runs on-demand without requiring a dedicated server process. Perfect for shared hosting environments.

## Features

- 🚀 **No dedicated server required** - Runs on any PHP-enabled web server
- 📤 **Drag-and-drop upload** - Easy file upload interface
- 🔄 **Automatic processing** - Fixes PDFs with a single click
- 🧹 **Self-cleaning** - Automatically removes old files
- 🔒 **Secure** - Input validation and file type checking
- 📱 **Responsive** - Works on desktop and mobile devices

## Requirements

- PHP 5.6 or higher
- Web server (Apache, Nginx, etc.)
- Shell execution enabled (`exec()` function)
- Write permissions for temporary directory
- All PDF processing tools installed on the server

## Installation

### 1. Quick Setup (Apache)

1. Copy the `php-app` folder to your web server document root
2. Ensure the parent directory contains `fix-pdf-fonts-interactive.sh`
3. Make the script executable:
   ```bash
   chmod +x ../fix-pdf-fonts-interactive.sh
   ```
4. Access via web browser: `http://yourserver/php-app/`

### 2. Nginx Configuration

Add to your Nginx server block:

```nginx
location /php-app {
    try_files $uri $uri/ /php-app/index.php?$query_string;
}

location ~ \.php$ {
    fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
    
    # Increase limits for file uploads
    client_max_body_size 100M;
    fastcgi_read_timeout 300;
}
```

### 3. AlmaLinux 9 / RHEL 9 / CentOS Stream 9

```bash
# Install required packages
sudo dnf install -y httpd php php-fpm pdftk poppler-utils ImageMagick qpdf ghostscript

# Copy files
sudo cp -r php-app /var/www/html/pdf-fixer
sudo chown -R apache:apache /var/www/html/pdf-fixer

# Configure Apache for larger uploads
sudo tee /etc/httpd/conf.d/pdf-fixer.conf << 'EOF'
<Directory "/var/www/html/pdf-fixer">
    AllowOverride All
    Require all granted
    php_value upload_max_filesize 100M
    php_value post_max_size 100M
    php_value max_execution_time 300
EOF

# Start Apache and configure SELinux
sudo systemctl enable --now httpd
sudo setsebool -P httpd_exec_mem on
```

### 4. Ubuntu/Debian

```bash
# Install packages
sudo apt install -y apache2 php libapache2-mod-php pdftk poppler-utils imagemagick qpdf ghostscript

# Copy and configure (similar to AlmaLinux, use www-data instead of apache)
sudo cp -r php-app /var/www/html/pdf-fixer
sudo chown -R www-data:www-data /var/www/html/pdf-fixer
```

### 5. Shared Hosting

1. Upload the `php-app` folder via FTP/cPanel
2. Ensure PHP settings allow:
   - `upload_max_filesize` = 100M
   - `post_max_size` = 100M
   - `max_execution_time` = 300
3. Contact your host if shell execution is disabled

## Configuration

Edit these constants in `index.php` to customize:

```php
define('MAX_FILE_SIZE', 100 * 1024 * 1024);  // Maximum upload size
define('CLEANUP_AGE', 3600);                  // Delete files after 1 hour
define('SCRIPT_PATH', dirname(__DIR__) . '/fix-pdf-fonts-interactive.sh');
```

## Security Considerations

- The `.htaccess` file includes security headers (Apache only)
- File uploads are validated for type and size
- Temporary files are stored outside web root when possible
- All user inputs are sanitized
- Old files are automatically cleaned up

## Troubleshooting

### "Processing script not found" error
- Ensure `fix-pdf-fonts-interactive.sh` exists in the parent directory
- Check the `SCRIPT_PATH` constant in `index.php`

### "PDF processing failed" error
- Verify all PDF tools are installed on the server
- Check if `exec()` function is enabled in PHP
- Review server error logs for details

### Upload fails immediately
- Check PHP upload limits in `php.ini` or `.htaccess`
- Verify write permissions on temp directory
- Ensure adequate disk space

### Works locally but not on server
- Many shared hosts disable `exec()` for security
- Contact hosting provider about shell execution
- Consider VPS or dedicated hosting for full functionality

## Testing

Test the installation:
```bash
# Check if exec() is available
php -r "echo exec('echo test');"

# Verify script is accessible
php -r "echo file_exists('../fix-pdf-fonts-interactive.sh') ? 'Found' : 'Not found';"

# Test PDF tools
which pdftk || which pdftk-java
which pdfinfo
which pdftoppm
```

## Performance Notes

- Processing time depends on PDF size and server resources
- Large PDFs (>50MB) may timeout on slow servers
- Consider increasing PHP timeout limits for large files
- The tool processes synchronously (no background jobs)

## Alternative Deployment

For better performance and reliability, consider:
- Using the Python Flask version with a proper WSGI server
- Running the command-line tool directly via cron jobs
- Setting up a job queue system for async processing