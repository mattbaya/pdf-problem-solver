# PDF Problem Solver - Deployment Documentation

## System Overview

**Server**: dev.svaha.com (AlmaLinux 10)
**Application**: Flask-based PDF font fixer with async processing and email notifications
**URL**: https://dev.svaha.com/
**Application User**: pdfx (uid: 989)

## Architecture

```
Internet → Apache (HTTPS) → Gunicorn → Flask App → Background Thread → Shell Script → ImageMagick/Poppler
                                                                      ↓
                                                               Email (Postfix)
```

## User & Permissions

### Application User: pdfx
- **UID/GID**: 989/989
- **Home Directory**: /opt/web/pdf-problem-solver
- **Shell**: /bin/bash
- **Type**: System user (created with -r flag)
- **Purpose**: Dedicated user for running PDF processing application

### Ownership Structure
```
/opt/web/pdf-problem-solver/          - pdfx:pdfx
├── web-app/                          - pdfx:pdfx
│   ├── venv/                         - pdfx:pdfx (Python virtual environment)
│   ├── app_async.py                  - pdfx:pdfx (Main Flask application)
│   └── templates/                    - pdfx:pdfx
├── *.sh scripts                      - pdfx:pdfx (Executable by pdfx)
└── fix-pdf-fonts-auto.sh             - pdfx:pdfx (PDF processing script)

/tmp/pdf-uploads/                     - pdfx:pdfx (Upload directory)
/var/log/pdf-problem-solver-*.log     - pdfx:pdfx (Application logs)
```

## Service Configuration

### Systemd Service
**File**: /etc/systemd/system/pdf-problem-solver.service

```ini
[Unit]
Description=PDF Problem Solver Flask Application
After=network.target

[Service]
Type=notify
User=pdfx
Group=pdfx
WorkingDirectory=/opt/web/pdf-problem-solver/web-app
Environment="PATH=/opt/web/pdf-problem-solver/web-app/venv/bin"
ExecStart=/opt/web/pdf-problem-solver/web-app/venv/bin/gunicorn \
    --workers 3 \
    --bind 127.0.0.1:5000 \
    --timeout 300 \
    --worker-class sync \
    --threads 2 \
    --access-logfile /var/log/pdf-problem-solver-access.log \
    --error-logfile /var/log/pdf-problem-solver-error.log \
    app_async:app

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Control Commands**:
```bash
systemctl start pdf-problem-solver
systemctl stop pdf-problem-solver
systemctl restart pdf-problem-solver
systemctl status pdf-problem-solver
journalctl -u pdf-problem-solver -f
```

## Apache Configuration

**File**: /etc/httpd/conf.d/pdf-problem-solver.conf

- SSL enforced (Let's Encrypt certificates)
- Reverse proxy to Gunicorn on port 5000
- 300-second timeout for large PDFs
- 100MB upload limit
- Security headers enabled

## Application Features

### 1. Async PDF Processing
- Background threading prevents timeouts
- Memory-limited ImageMagick (512MB memory, 1GB map)
- 300-second timeout per request

### 2. Email Notifications
- SMTP via local Postfix (localhost:25)
- Sender: noreply@dev.svaha.com
- HTML emails with download links
- 24-hour link expiration

### 3. Security Features
- Rate limiting: 5 uploads per IP per hour
- Email validation (RFC 5322 + dangerous character blocking)
- Filename sanitization (double-pass)
- Path traversal prevention
- UUID-based job IDs
- Security headers (CSP, HSTS, X-Frame-Options, etc.)

### 4. Resource Management
- Daily cleanup cron job (3 AM)
- Removes files older than 24 hours
- Prevents disk space exhaustion

## Dependencies

### System Packages
- ghostscript
- poppler-utils
- qpdf
- ImageMagick
- pdftk-java (requires Java 21 OpenJDK)
- postfix

### Python Packages (in virtualenv)
- Flask
- gunicorn
- flask-mail
- werkzeug

## Logs & Monitoring

### Application Logs
```bash
# Access log
tail -f /var/log/pdf-problem-solver-access.log

# Error log
tail -f /var/log/pdf-problem-solver-error.log

# System journal
journalctl -u pdf-problem-solver -f
```

### Apache Logs
```bash
tail -f /var/log/httpd/dev.svaha.com-ssl-access.log
tail -f /var/log/httpd/dev.svaha.com-ssl-error.log
```

### Cleanup Log
```bash
tail -f /var/log/pdf-cleanup.log
```

## Cron Jobs

```cron
# Database backup (2 AM)
0 2 * * * /root/scripts/backup-mariadb.sh

# Website backup (3 AM)
0 3 * * * /root/scripts/backup-website.sh

# PDF cleanup (3 AM)
0 3 * * * /root/scripts/cleanup-old-pdfs.sh

# Monitoring (every 6 hours)
0 */6 * * * /root/scripts/monitoring/check-disk-space.sh
0 */6 * * * /root/scripts/monitoring/check-services.sh
0 */6 * * * /root/scripts/monitoring/check-ssl-cert.sh
```

## Troubleshooting

### Service Won't Start
```bash
# Check logs
journalctl -u pdf-problem-solver -n 50 --no-pager

# Verify user exists
id pdfx

# Check file permissions
ls -la /opt/web/pdf-problem-solver/web-app/

# Test gunicorn manually
sudo -u pdfx /opt/web/pdf-problem-solver/web-app/venv/bin/gunicorn \
  --bind 127.0.0.1:5000 app_async:app
```

### PDF Processing Fails
```bash
# Check available memory
free -h

# Check ImageMagick limits
magick -list resource

# Test script manually
sudo -u pdfx /opt/web/pdf-problem-solver/fix-pdf-fonts-auto.sh \
  /tmp/test.pdf /tmp/output.pdf

# Check script PATH
grep PATH /opt/web/pdf-problem-solver/fix-pdf-fonts-auto.sh
```

### Email Not Sending
```bash
# Check Postfix
systemctl status postfix

# Test email
echo "Test" | mail -s "Test" your@email.com

# Check mail queue
mailq

# Check Postfix logs
tail -f /var/log/maillog
```

### Permission Issues
```bash
# Fix ownership recursively
chown -R pdfx:pdfx /opt/web/pdf-problem-solver/

# Fix log files
chown pdfx:pdfx /var/log/pdf-problem-solver-*.log

# Fix upload directory
mkdir -p /tmp/pdf-uploads
chown pdfx:pdfx /tmp/pdf-uploads
```

## Deployment Checklist

- [x] Create pdfx user
- [x] Transfer ownership to pdfx
- [x] Update systemd service (User=pdfx)
- [x] Update log file ownership
- [x] Update upload directory ownership
- [x] Restart service
- [x] Verify application responds
- [x] Test PDF upload
- [x] Verify email sending

## Security Hardening Applied

See `/root/SECURITY.md` for comprehensive security documentation.

**Key Security Measures**:
- Dedicated application user (pdfx)
- Input validation & sanitization
- Rate limiting (5 uploads/IP/hour)
- Security headers (CSP, HSTS, X-Frame-Options)
- Path traversal prevention
- UUID-based file access
- Automated cleanup of old files
- CSF firewall with LFD
- SSL/TLS enforced

## Backup & Recovery

### Files to Backup
- `/opt/web/pdf-problem-solver/` (application code)
- `/etc/httpd/conf.d/pdf-problem-solver.conf` (Apache config)
- `/etc/systemd/system/pdf-problem-solver.service` (systemd service)
- Database: MariaDB (automatic daily backup)

### Recovery Procedure
1. Restore application files to /opt/web/pdf-problem-solver/
2. Restore Apache and systemd configs
3. Create pdfx user if needed
4. Set ownership: `chown -R pdfx:pdfx /opt/web/pdf-problem-solver/`
5. Restart services: `systemctl restart httpd pdf-problem-solver`

## Maintenance

### Regular Tasks
- Monitor disk space (automated via cron)
- Review logs for errors
- Check service status
- Verify SSL certificate expiration (automated)
- Test PDF processing periodically

### Updates
```bash
# Update Python packages
cd /opt/web/pdf-problem-solver/web-app
source venv/bin/activate
pip install --upgrade flask gunicorn flask-mail

# Restart service
systemctl restart pdf-problem-solver
```

## Contact

**System Administrator**: root@dev.svaha.com
**Application Owner**: pdfx user
**Documentation Updated**: 2025-10-15
