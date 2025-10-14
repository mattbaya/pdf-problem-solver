# Web Application Deployment Guide

This guide covers deploying both the Flask and PHP versions of the PDF Font Fixer on various server environments.

## Overview

- **Flask App** (`web-app/`) - Python-based web server with advanced features
- **PHP App** (`php-app/`) - Lightweight, shared hosting-friendly version

Both apps provide the same core functionality: web-based PDF font fixing with drag-and-drop upload.

## AlmaLinux 9 / RHEL 9 / CentOS Stream 9 Deployment

### Prerequisites

Install required packages:
```bash
# Install PDF processing tools
sudo dnf install -y pdftk poppler-utils ImageMagick qpdf ghostscript

# For PHP version
sudo dnf install -y httpd php php-fpm

# For Flask version  
sudo dnf install -y python3 python3-pip python3-venv nginx
```

### Flask App Deployment

#### Option 1: Systemd Service (Recommended)

1. **Setup application:**
```bash
cd /opt
sudo git clone <your-repo> pdf-fixer
cd pdf-fixer/web-app
sudo python3 -m venv venv
sudo venv/bin/pip install -r requirements.txt gunicorn
```

2. **Create systemd service:**
```bash
sudo tee /etc/systemd/system/pdf-fixer.service << 'EOF'
[Unit]
Description=PDF Fixer Flask App
After=network.target

[Service]
Type=notify
User=apache
Group=apache
WorkingDirectory=/opt/pdf-fixer/web-app
Environment=PATH=/opt/pdf-fixer/web-app/venv/bin
ExecStart=/opt/pdf-fixer/web-app/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 2 --timeout 300 app:app
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```

3. **Configure Nginx proxy:**
```bash
sudo tee /etc/nginx/conf.d/pdf-fixer.conf << 'EOF'
server {
    listen 80;
    server_name your-domain.com;
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        send_timeout 300;
    }
}
EOF
```

4. **Start services:**
```bash
sudo systemctl enable --now pdf-fixer nginx
sudo setsebool -P httpd_can_network_connect on  # SELinux
```

#### Option 2: Direct Python Server (Development)

```bash
cd web-app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

### PHP App Deployment

#### Apache Setup

1. **Copy files:**
```bash
sudo cp -r php-app /var/www/html/pdf-fixer
sudo chown -R apache:apache /var/www/html/pdf-fixer
sudo chmod 755 /var/www/html/pdf-fixer
```

2. **Configure Apache:**
```bash
sudo tee /etc/httpd/conf.d/pdf-fixer.conf << 'EOF'
<Directory "/var/www/html/pdf-fixer">
    AllowOverride All
    Require all granted
    
    # PHP configuration
    php_value upload_max_filesize 100M
    php_value post_max_size 100M
    php_value max_execution_time 300
    php_value max_input_time 300
</Directory>
EOF
```

3. **Start Apache:**
```bash
sudo systemctl enable --now httpd
sudo setsebool -P httpd_exec_mem on  # SELinux for exec()
```

#### Nginx + PHP-FPM Setup

1. **Copy files and set permissions:**
```bash
sudo cp -r php-app /var/www/html/pdf-fixer
sudo chown -R nginx:nginx /var/www/html/pdf-fixer
```

2. **Configure PHP-FPM:**
```bash
sudo tee -a /etc/php-fpm.d/www.conf << 'EOF'
php_value[upload_max_filesize] = 100M
php_value[post_max_size] = 100M
php_value[max_execution_time] = 300
php_value[max_input_time] = 300
EOF
```

3. **Configure Nginx:**
```bash
sudo tee /etc/nginx/conf.d/pdf-fixer.conf << 'EOF'
server {
    listen 80;
    server_name your-domain.com;
    root /var/www/html/pdf-fixer;
    index index.php;
    client_max_body_size 100M;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }
}
EOF
```

4. **Start services:**
```bash
sudo systemctl enable --now nginx php-fpm
```

## Ubuntu/Debian Deployment

### Package Installation
```bash
# PDF tools
sudo apt update
sudo apt install -y pdftk poppler-utils imagemagick qpdf ghostscript

# Web servers
sudo apt install -y apache2 php libapache2-mod-php  # For PHP
sudo apt install -y nginx python3 python3-pip python3-venv  # For Flask
```

### Configuration
Follow the same configuration steps as AlmaLinux, but use:
- `www-data` instead of `apache` user
- `/etc/apache2/sites-available/` for Apache virtual hosts
- `systemctl` commands work the same

## Shared Hosting Deployment

### PHP App (Recommended for Shared Hosting)

1. **Upload files** via FTP/cPanel to your domain folder
2. **Ensure shell execution** is enabled (contact host if needed)
3. **Check PHP limits** in cPanel or contact support:
   - `upload_max_filesize` ≥ 100M
   - `post_max_size` ≥ 100M
   - `max_execution_time` ≥ 300

### Flask App (Limited Support)
Most shared hosts don't support Flask. Consider:
- **VPS providers**: DigitalOcean, Linode, Vultr
- **Cloud platforms**: Heroku, Railway, PythonAnywhere

## Troubleshooting

### Permission Issues
```bash
# Fix file permissions
sudo chown -R apache:apache /var/www/html/pdf-fixer  # RHEL/CentOS
sudo chown -R www-data:www-data /var/www/html/pdf-fixer  # Ubuntu/Debian

# Fix shell script permissions
sudo chmod +x /opt/pdf-fixer/fix-pdf-fonts-interactive.sh
```

### SELinux Issues (RHEL/CentOS/AlmaLinux)
```bash
# Allow web server to execute binaries
sudo setsebool -P httpd_exec_mem on

# Allow network connections (for Flask proxy)
sudo setsebool -P httpd_can_network_connect on

# Fix file contexts
sudo restorecon -R /var/www/html/pdf-fixer
sudo restorecon -R /opt/pdf-fixer
```

### PDF Tool Issues
```bash
# Test tools are working
pdftk --version
pdfinfo -v
convert -version
gs --version

# Check if tools are in PATH
which pdftk pdfinfo convert gs
```

### PHP exec() Disabled
If `exec()` is disabled, you'll need to:
1. Contact hosting provider to enable it
2. Use VPS/dedicated hosting instead
3. Consider using a PDF API service

### Large File Timeouts
Increase timeouts in web server and PHP configuration:
```bash
# Nginx
proxy_connect_timeout 300;
proxy_read_timeout 300;

# Apache
Timeout 300

# PHP
max_execution_time = 300
max_input_time = 300
```

## Security Considerations

1. **File Upload Validation** - Both apps validate file types and sizes
2. **Temporary File Cleanup** - Files are automatically cleaned up
3. **Input Sanitization** - All user inputs are sanitized
4. **Directory Traversal Protection** - Paths are validated
5. **SELinux/AppArmor** - Enable for additional security

## Monitoring and Maintenance

### Log Files
- **Flask**: Check systemd journal: `sudo journalctl -u pdf-fixer -f`
- **PHP**: Check Apache/Nginx error logs in `/var/log/`
- **Application**: Both apps log errors to web server error logs

### Automatic Cleanup
Both applications automatically clean up old files, but you can add a cron job for extra safety:
```bash
# Clean up temp files older than 1 hour
0 * * * * find /tmp/pdf-fixer/ -type f -mmin +60 -delete 2>/dev/null
```

### Updates
```bash
# Update code
cd /opt/pdf-fixer
sudo git pull

# Restart Flask service
sudo systemctl restart pdf-fixer

# PHP updates take effect immediately
```