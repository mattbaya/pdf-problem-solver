# PDF Problem Solver - PHP App Deployment Guide

## Overview

The PHP application is designed for shared hosting environments and doesn't require a dedicated server process. It works with any web server that supports PHP (Apache, Nginx, etc.).

## Requirements

- PHP 7.4 or higher
- Shell access (for executing bash scripts)
- System tools: pdftk, poppler-utils, imagemagick, ghostscript, qpdf, tesseract

## Configuration

The PHP application uses **no hardcoded server names or URLs**. All paths are relative and will work on any domain.

### PHP Settings

Required PHP settings for PDF processing:

```ini
upload_max_filesize = 100M
post_max_size = 100M
max_execution_time = 300
memory_limit = 512M
```

### Apache Configuration

#### Using .htaccess (Shared Hosting)

The included `.htaccess` file handles most configuration:

```apache
# Increase upload limits
php_value upload_max_filesize 100M
php_value post_max_size 100M
php_value max_execution_time 300
php_value memory_limit 512M

# Security
Options -Indexes
RewriteEngine On

# Redirect to HTTPS (optional)
# RewriteCond %{HTTPS} off
# RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
```

#### Virtual Host Configuration

For dedicated servers or VPS:

```apache
<VirtualHost *:80>
    ServerName your-domain.com
    DocumentRoot /path/to/pdf-problem-solver/php-app

    <Directory /path/to/pdf-problem-solver/php-app>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted

        # PHP settings
        php_value upload_max_filesize 100M
        php_value post_max_size 100M
        php_value max_execution_time 300
        php_value memory_limit 512M
    </Directory>

    # Error and access logs
    ErrorLog ${APACHE_LOG_DIR}/pdf-solver-error.log
    CustomLog ${APACHE_LOG_DIR}/pdf-solver-access.log combined
</VirtualHost>
```

### Nginx Configuration

For Nginx with PHP-FPM:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    root /path/to/pdf-problem-solver/php-app;
    index index.php;

    client_max_body_size 100M;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;

        # Increase timeouts for PDF processing
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
    }

    # Deny access to sensitive files
    location ~ /\.ht {
        deny all;
    }
}
```

### PHP-FPM Configuration

Edit `/etc/php/8.1/fpm/php.ini`:

```ini
upload_max_filesize = 100M
post_max_size = 100M
max_execution_time = 300
memory_limit = 512M
```

Edit `/etc/php/8.1/fpm/pool.d/www.conf`:

```ini
request_terminate_timeout = 300
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
```

Restart PHP-FPM:
```bash
sudo systemctl restart php8.1-fpm
```

## File Permissions

Set proper permissions:

```bash
# Make scripts executable
chmod +x ../fix-pdf-fonts-interactive.sh
chmod +x ../additional-tools/*.sh

# Set proper ownership (Apache/Nginx user)
sudo chown -R www-data:www-data /path/to/pdf-problem-solver

# Allow PHP to write to temp directory
chmod 755 /tmp
```

## Deployment Methods

### 1. Shared Hosting (cPanel, Plesk, etc.)

1. Upload all files via FTP/SFTP
2. Set file permissions (scripts executable)
3. Update `.htaccess` if needed
4. Access via your domain

**Note:** Some shared hosts restrict shell_exec(). Check with your provider.

### 2. VPS / Dedicated Server

```bash
# Clone or copy files
cd /var/www
sudo cp -r /path/to/pdf-problem-solver/php-app pdf-solver

# Set ownership
sudo chown -R www-data:www-data /var/www/pdf-solver

# Make scripts executable
chmod +x /var/www/pdf-solver/../fix-pdf-fonts-interactive.sh
chmod +x /var/www/pdf-solver/../additional-tools/*.sh

# Configure Apache/Nginx virtual host
sudo nano /etc/apache2/sites-available/pdf-solver.conf
sudo a2ensite pdf-solver
sudo systemctl reload apache2
```

### 3. Docker Container

Create `Dockerfile`:

```dockerfile
FROM php:8.1-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pdftk \
    poppler-utils \
    imagemagick \
    ghostscript \
    qpdf \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

# Enable Apache modules
RUN a2enmod rewrite

# Copy application files
COPY . /var/www/html/

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod +x /var/www/html/../*.sh \
    && chmod +x /var/www/html/../additional-tools/*.sh

# PHP configuration
RUN echo "upload_max_filesize = 100M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size = 100M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/uploads.ini

EXPOSE 80
```

Build and run:
```bash
docker build -t pdf-problem-solver-php .
docker run -p 80:80 pdf-problem-solver-php
```

## URLs and Endpoints

The application is self-contained and works on any domain:

- **Main page:** `http://your-domain.com/` or `http://your-domain.com/index.php`
- **Upload:** POST to `index.php?action=upload`
- **Process:** POST to `index.php?action=process`
- **Download:** GET `index.php?download=1&file={filename}`
- **Cleanup:** POST to `index.php?action=cleanup`

All URLs are relative - no configuration needed!

## Temporary File Management

The application automatically:
- Creates temp files in `sys_get_temp_dir() . '/pdf-fixer/'`
- Cleans up files older than 1 hour on each request
- Cleans up files after download

You can also set up a cron job for additional cleanup:

```bash
# Crontab entry - clean old files every hour
0 * * * * find /tmp/pdf-fixer -type f -mmin +60 -delete
```

## Security

### Production Security Checklist

1. **Enable HTTPS** - Use Let's Encrypt or other SSL certificate
   ```apache
   <VirtualHost *:443>
       SSLEngine on
       SSLCertificateFile /path/to/cert.pem
       SSLCertificateKeyFile /path/to/key.pem
   </VirtualHost>
   ```

2. **Restrict file uploads** - Already limited to PDF files only

3. **Validate inputs** - All inputs are sanitized and validated

4. **Disable directory listing** - `Options -Indexes` in .htaccess

5. **Hide PHP version**
   ```ini
   expose_php = Off
   ```

6. **Rate limiting** - Use fail2ban or mod_evasive

7. **File permissions** - Scripts executable, data directories writable

## Testing

Test the application:

```bash
# Check PHP configuration
php -i | grep -E "upload_max_filesize|post_max_size|max_execution_time"

# Check if scripts are executable
ls -la ../fix-pdf-fonts-interactive.sh

# Check system dependencies
which pdftk pdfinfo pdftoppm magick gs qpdf tesseract

# Test file upload (using curl)
curl -F "file=@test.pdf" http://your-domain.com/index.php
```

## Troubleshooting

### Script execution fails

**Problem:** PHP can't execute bash scripts

**Solution:**
```bash
# Check PHP settings
php -i | grep disable_functions

# Ensure shell_exec is not disabled
# Edit php.ini and remove shell_exec from disable_functions
```

### Upload fails

**Problem:** File too large or upload rejected

**Solution:**
```bash
# Check PHP limits
php -i | grep upload_max_filesize

# Increase limits in php.ini or .htaccess
```

### Permission denied

**Problem:** Can't write to temp directory

**Solution:**
```bash
# Check temp directory
php -r "echo sys_get_temp_dir();"

# Set permissions
chmod 777 /tmp/pdf-fixer
```

### Processing timeout

**Problem:** PDF processing takes too long

**Solution:**
```ini
# Increase timeout in php.ini
max_execution_time = 600
set_time_limit(600)
```

## Performance Optimization

### PHP OpCache

Enable OpCache for better performance:

```ini
opcache.enable=1
opcache.memory_consumption=128
opcache.max_accelerated_files=10000
opcache.validate_timestamps=0
```

### Apache MPM

Use event or worker MPM for better concurrency:

```bash
sudo a2dismod mpm_prefork
sudo a2enmod mpm_event
sudo systemctl restart apache2
```

### Nginx + PHP-FPM

Use Nginx with PHP-FPM for better performance than Apache.

### CDN

Serve static assets from a CDN to reduce server load.

## Monitoring

Monitor these metrics:
- **Disk space** - `/tmp/pdf-fixer/` usage
- **CPU usage** - PDF processing is CPU intensive
- **Memory usage** - Watch for memory limit errors
- **Error logs** - Check Apache/Nginx error logs
- **Processing times** - Track slow requests

```bash
# Watch disk usage
watch -n 60 'du -sh /tmp/pdf-fixer'

# Monitor Apache logs
tail -f /var/log/apache2/error.log

# Monitor Nginx logs
tail -f /var/log/nginx/error.log
```

## Backup and Maintenance

Regular maintenance tasks:

```bash
# Clear old temp files
find /tmp/pdf-fixer -type f -mtime +1 -delete

# Backup application
tar -czf pdf-solver-backup.tar.gz /path/to/php-app

# Update scripts
git pull  # if using git
chmod +x ../*.sh
```

## Support

For issues:
1. Check error logs (Apache/Nginx/PHP)
2. Verify dependencies are installed
3. Check file permissions
4. Test with small PDF first
5. Review processing pipeline documentation
