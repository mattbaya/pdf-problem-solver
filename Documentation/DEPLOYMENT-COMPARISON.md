# Deployment Options Comparison

Quick guide to choosing the best deployment option for your PDF Font Fixer web application.

## Deployment Options Summary

| Feature | Command Line | Flask Web App | PHP Web App |
|---------|-------------|---------------|-------------|
| **Setup Complexity** | Simple | Moderate | Simple |
| **Server Requirements** | None (local) | Python, WSGI server | PHP-enabled web server |
| **Shared Hosting** | N/A | No | Yes |
| **VPS/Dedicated** | Yes | Yes | Yes |
| **Concurrent Users** | Single user | High | Medium |
| **Memory Usage** | Low | Medium-High | Low |
| **Process Management** | Manual | Systemd service | On-demand |
| **Auto-restart** | No | Yes | N/A |

## Detailed Breakdown

### 1. Command Line Tool (Traditional)
```bash
./fix-pdf-fonts-interactive.sh
```

**Best for:**
- Individual users
- Local processing
- Automation/scripting
- Learning the tool

**Requirements:**
- macOS (automatic setup) or Linux (manual setup)
- Terminal access
- Local file system

**Pros:**
- No server setup needed
- Full control over processing
- Works offline
- Handles any file size

**Cons:**
- Single user only
- Requires technical knowledge
- No web interface

### 2. Flask Web App (Python)
```bash
cd web-app && python app.py
```

**Best for:**
- Organizations with multiple users
- VPS/dedicated servers
- High-volume processing
- Advanced features

**Requirements:**
- Python 3.7+
- WSGI server (Gunicorn, uWSGI)
- Reverse proxy (Nginx, Apache)
- Process management (systemd)

**Pros:**
- Professional web interface
- Concurrent processing
- Easy integration with existing Python infrastructure
- Advanced error handling
- Scalable

**Cons:**
- More complex setup
- Requires dedicated server or VPS
- Higher memory usage
- Not suitable for shared hosting

### 3. PHP Web App
```bash
# Just copy to web server
cp -r php-app /var/www/html/
```

**Best for:**
- Shared hosting environments
- Simple deployment needs
- Budget hosting solutions
- Quick setup

**Requirements:**
- PHP 5.6+
- Web server (Apache/Nginx)
- PDF tools installed on server
- exec() function enabled

**Pros:**
- Works on shared hosting
- Simple deployment (copy files)
- No background processes needed
- Low resource usage
- Familiar technology stack

**Cons:**
- Limited to server capabilities
- Single-threaded processing
- May timeout on large files
- Depends on hosting provider policies

## Server Environment Recommendations

### AlmaLinux 9 / RHEL 9 / CentOS Stream 9

#### For PHP App (Recommended for simplicity):
```bash
sudo dnf install -y httpd php pdftk poppler-utils ImageMagick
sudo cp -r php-app /var/www/html/pdf-fixer
sudo systemctl enable --now httpd
```

#### For Flask App (Recommended for performance):
```bash
sudo dnf install -y python3 nginx pdftk poppler-utils ImageMagick
# Setup with systemd service + Nginx proxy
```

### Ubuntu/Debian
Same approach, but use `apt` instead of `dnf` and `www-data` instead of `apache` user.

### Shared Hosting
Only PHP app will work. Upload via FTP/cPanel and ensure PDF tools are available.

## Decision Matrix

### Choose Command Line If:
- You're the only user
- Processing PDFs locally
- Automating with scripts
- Learning or testing the tool

### Choose Flask Web App If:
- Multiple users need access
- You have a VPS/dedicated server
- Need professional interface
- Want advanced features
- Expecting high volume

### Choose PHP Web App If:
- Using shared hosting
- Want simple deployment
- Need basic web interface
- Budget hosting constraints
- Familiar with PHP

## Migration Path

You can start with one option and migrate later:

1. **Command Line → PHP App**: Copy `php-app/` to web server
2. **PHP App → Flask App**: Deploy Flask version alongside PHP
3. **Command Line → Flask App**: Deploy Flask version on VPS

All versions use the same core shell script, so your PDFs will be processed identically regardless of the interface.

## Resource Requirements

### Command Line
- **CPU**: Minimal (during processing)
- **RAM**: 100-500MB during processing
- **Storage**: Temporary files (2-3x PDF size)

### Flask Web App
- **CPU**: 1-2 cores minimum
- **RAM**: 512MB-2GB (depending on concurrent users)
- **Storage**: Temporary files + application files

### PHP Web App
- **CPU**: Shared hosting typically sufficient
- **RAM**: 128-512MB per request
- **Storage**: Temporary files (cleaned automatically)

## Security Considerations

All versions include:
- File type validation
- Size limits
- Input sanitization
- Temporary file cleanup

Additional considerations:
- **Flask**: Run behind reverse proxy, use HTTPS
- **PHP**: Ensure exec() is properly secured
- **Command Line**: Local file system security

## Support and Maintenance

- **Command Line**: Self-contained, minimal maintenance
- **Flask**: Monitor service, log rotation, updates
- **PHP**: Web server maintenance, PHP updates