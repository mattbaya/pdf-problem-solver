# PDF Problem Solver - Web App Deployment Guide

## Configuration

The Flask web application uses environment variables for configuration, so no server names or ports are hardcoded.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FLASK_HOST` | `0.0.0.0` | Host to bind to (0.0.0.0 = all interfaces) |
| `FLASK_PORT` | `5000` | Port to listen on |
| `FLASK_DEBUG` | `False` | Enable debug mode (use `true` or `false`) |

### Running the Application

#### Development (using built-in Flask server)

```bash
# Run with defaults (0.0.0.0:5000)
python app.py

# Run on specific port
FLASK_PORT=8080 python app.py

# Run on localhost only
FLASK_HOST=127.0.0.1 python app.py

# Run with debug mode enabled
FLASK_DEBUG=true python app.py

# Combine multiple options
FLASK_HOST=0.0.0.0 FLASK_PORT=8080 FLASK_DEBUG=false python app.py
```

#### Production (using Gunicorn)

For production deployments, use Gunicorn instead of the built-in Flask server:

```bash
# Install gunicorn if not already installed
pip install gunicorn

# Run with 4 worker processes
gunicorn -w 4 -b 0.0.0.0:5000 app:app

# Run on different host/port
gunicorn -w 4 -b your-server.com:8080 app:app

# Run with specific settings
gunicorn -w 4 -b 0.0.0.0:5000 --timeout 300 --access-logfile - app:app
```

**Recommended Gunicorn settings for PDF processing:**
- Workers: 2-4 (PDF processing is CPU intensive)
- Timeout: 300+ seconds (large PDFs take time)
- Worker class: `sync` (default, good for CPU-bound tasks)

#### Production (using uWSGI)

Alternative to Gunicorn:

```bash
# Install uwsgi
pip install uwsgi

# Run with uwsgi
uwsgi --http 0.0.0.0:5000 --wsgi-file app.py --callable app --processes 4
```

### Nginx Reverse Proxy Configuration

For production, put Nginx in front of your Flask application:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    client_max_body_size 100M;  # Match Flask's max file size

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Increase timeouts for large PDF processing
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        send_timeout 300;
    }
}
```

### Apache Configuration (for PHP app)

The PHP application can run on Apache with mod_php:

```apache
<VirtualHost *:80>
    ServerName your-domain.com
    DocumentRoot /path/to/pdf-problem-solver/php-app

    <Directory /path/to/pdf-problem-solver/php-app>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted

        # Increase limits for PDF processing
        php_value upload_max_filesize 100M
        php_value post_max_size 100M
        php_value max_execution_time 300
        php_value memory_limit 512M
    </Directory>
</VirtualHost>
```

### Environment-Specific Configuration

Create a `.env` file for environment-specific settings:

```bash
# .env file
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
FLASK_DEBUG=false
```

Load it in your shell:
```bash
export $(cat .env | xargs)
python app.py
```

Or use python-dotenv:
```bash
pip install python-dotenv
```

Add to `app.py`:
```python
from dotenv import load_dotenv
load_dotenv()
```

### Systemd Service (Linux)

Create `/etc/systemd/system/pdf-problem-solver.service`:

```ini
[Unit]
Description=PDF Problem Solver Web Application
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/web/pdf-problem-solver/web-app
Environment="FLASK_HOST=0.0.0.0"
Environment="FLASK_PORT=5000"
Environment="FLASK_DEBUG=false"
ExecStart=/opt/web/pdf-problem-solver/web-app/venv/bin/gunicorn -w 4 -b 0.0.0.0:5000 --timeout 300 app:app
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable pdf-problem-solver
sudo systemctl start pdf-problem-solver
sudo systemctl status pdf-problem-solver
```

### Docker Deployment

Create `Dockerfile`:

```dockerfile
FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pdftk \
    poppler-utils \
    imagemagick \
    ghostscript \
    qpdf \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Use environment variables for configuration
ENV FLASK_HOST=0.0.0.0
ENV FLASK_PORT=5000
ENV FLASK_DEBUG=false

EXPOSE 5000

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "--timeout", "300", "app:app"]
```

Build and run:
```bash
docker build -t pdf-problem-solver .
docker run -p 5000:5000 pdf-problem-solver
```

### Security Considerations

1. **Never run with debug=true in production**
2. **Use HTTPS** - Configure SSL/TLS certificates
3. **File size limits** - Already set to 100MB
4. **Temporary file cleanup** - Automatic cleanup on 1-hour timer
5. **Input validation** - All inputs are validated
6. **Rate limiting** - Consider adding rate limiting for production

### Monitoring

Monitor these aspects:
- **Disk space** - Temporary files in `/tmp/pdf-fixer/`
- **CPU usage** - PDF processing is CPU intensive
- **Memory usage** - Large PDFs use significant RAM
- **Processing time** - Track average processing times
- **Error rates** - Monitor failed conversions

### Troubleshooting

**Port already in use:**
```bash
# Change port
FLASK_PORT=8080 python app.py
```

**Permission denied:**
```bash
# Check upload directory permissions
ls -la /tmp/pdf-fixer/
```

**Dependencies missing:**
```bash
# Reinstall requirements
pip install -r requirements.txt
```

**Scripts not executable:**
```bash
# Make scripts executable
chmod +x ../fix-pdf-fonts-interactive.sh
chmod +x ../additional-tools/*.sh
```

### Performance Tuning

For high-traffic deployments:

1. **Use Gunicorn with multiple workers**
   ```bash
   gunicorn -w $(nproc) -b 0.0.0.0:5000 app:app
   ```

2. **Use faster storage** - Put temp files on SSD
   ```python
   app.config['UPLOAD_FOLDER'] = '/var/cache/pdf-fixer'
   ```

3. **Add Redis for job queuing** - Use Celery for async processing

4. **Load balancing** - Use multiple servers behind load balancer

5. **CDN** - Serve static assets from CDN
