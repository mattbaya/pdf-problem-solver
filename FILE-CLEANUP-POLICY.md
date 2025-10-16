# PDF Problem Solver - File Cleanup Policy

## Overview

All web applications now have a consistent **24-hour file retention policy** for processed PDF files.

## Cleanup Settings

### Universal Timeout
**24 hours (86400 seconds)** - Files are automatically deleted 24 hours after creation

### Implementation

#### Flask Apps (`app.py` and `app_async.py`)
```python
CLEANUP_AGE = 86400  # Clean files older than 24 hours (in seconds)

def cleanup_old_files():
    """Remove files older than CLEANUP_AGE seconds"""
    # Checks file modification time (mtime)
    # Deletes files older than CLEANUP_AGE
    # Runs on every page request
```

**Trigger:** Runs automatically on every request to the home page (`/`)

**Location:** `/tmp/pdf-uploads/` (or configured `UPLOAD_FOLDER`)

#### PHP App (`index.php`)
```php
define('CLEANUP_AGE', 86400); // Clean files older than 24 hours

function cleanup_old_files() {
    // Checks file modification time with filemtime()
    // Deletes files older than CLEANUP_AGE
    // Runs on every page load
}
```

**Trigger:** Runs automatically on every page load (line 17)

**Location:** `sys_get_temp_dir() . '/pdf-fixer/'`

## File Lifecycle

### Upload and Processing
1. **Upload** - User uploads PDF via web form
2. **Processing** - PDF is processed with selected options
3. **Available** - User can download for 24 hours
4. **Cleanup** - File automatically deleted after 24 hours

### Example Timeline
```
Hour 0:  User uploads PDF at 2:00 PM on Day 1
Hour 0:  Processing completes at 2:05 PM on Day 1
Hour 1:  User downloads at 3:00 PM on Day 1
Hour 24: File deleted at 2:05 PM on Day 2 (24 hours after creation)
```

## Email Notification

Email sent to users states:
> "This link will be available for 24 hours."

This accurately reflects the file retention policy.

## Manual Cleanup

### Force Cleanup (if needed)

**Flask:**
```bash
# Clean files in upload directory older than 24 hours
find /tmp/pdf-uploads -type f -mtime +1 -delete
```

**PHP:**
```bash
# Clean files in PHP temp directory older than 24 hours
find /tmp/pdf-fixer -type f -mtime +1 -delete
```

### Cron Job (optional)

Add a cron job for additional cleanup safety:

```bash
# Run cleanup daily at 3 AM
0 3 * * * find /tmp/pdf-uploads -type f -mtime +1 -delete
0 3 * * * find /tmp/pdf-fixer -type f -mtime +1 -delete
```

## Configuration

### Change Cleanup Age

To adjust the 24-hour timeout:

**Flask apps:**
```python
# In app.py or app_async.py
CLEANUP_AGE = 86400  # Change this value (in seconds)

# Examples:
CLEANUP_AGE = 3600    # 1 hour
CLEANUP_AGE = 43200   # 12 hours
CLEANUP_AGE = 86400   # 24 hours (current)
CLEANUP_AGE = 172800  # 48 hours
CLEANUP_AGE = 604800  # 7 days
```

**PHP app:**
```php
// In index.php
define('CLEANUP_AGE', 86400); // Change this value (in seconds)
```

### Disable Automatic Cleanup

**Flask apps:**
```python
# Comment out cleanup call in index route
@app.route('/')
def index():
    # cleanup_old_files()  # Disabled
    return render_template('index.html')
```

**PHP app:**
```php
// Comment out cleanup call at top of file
// cleanup_old_files();  // Disabled
```

## Monitoring

### Check Disk Usage

**Flask:**
```bash
# Check upload directory size
du -sh /tmp/pdf-uploads

# Count files
ls -l /tmp/pdf-uploads | wc -l

# Show oldest files
ls -lt /tmp/pdf-uploads | tail -10
```

**PHP:**
```bash
# Check upload directory size
du -sh /tmp/pdf-fixer

# Count files
ls -l /tmp/pdf-fixer | wc -l

# Show oldest files
ls -lt /tmp/pdf-fixer | tail -10
```

### Disk Space Alerts

Set up monitoring to alert when disk usage exceeds threshold:

```bash
# Add to monitoring script
USAGE=$(df /tmp | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $USAGE -gt 80 ]; then
    echo "WARNING: /tmp disk usage is ${USAGE}%"
fi
```

## Storage Estimates

Typical file sizes after processing:

| Original Size | Pages | Processing | Result Size | 24h Storage (100 users) |
|--------------|-------|------------|-------------|------------------------|
| 1 MB         | 5     | 600 DPI    | 5-10 MB     | 0.5-1 GB              |
| 5 MB         | 25    | 600 DPI    | 25-50 MB    | 2.5-5 GB              |
| 10 MB        | 50    | 600 DPI    | 50-100 MB   | 5-10 GB               |
| 20 MB        | 100   | 600 DPI    | 100-200 MB  | 10-20 GB              |

**Note:** Higher DPI settings produce larger files. With OCR and page numbers, files may be 20-30% larger.

## Best Practices

1. **Regular monitoring** - Check disk usage weekly
2. **Backup cleanup** - Add cron job for safety
3. **Alert thresholds** - Set up alerts at 80% disk usage
4. **Storage planning** - Ensure adequate disk space for expected load
5. **Log rotation** - Rotate application logs to free space

## Troubleshooting

### Files not being cleaned up

**Check:**
1. Verify cleanup function is being called
2. Check file permissions (web server needs write access)
3. Look for errors in application logs
4. Verify CLEANUP_AGE setting

**Manual fix:**
```bash
# Force cleanup
find /tmp/pdf-uploads -type f -mtime +1 -delete
find /tmp/pdf-fixer -type f -mtime +1 -delete
```

### Disk space full

**Immediate action:**
```bash
# Clean all processed files
rm -rf /tmp/pdf-uploads/*
rm -rf /tmp/pdf-fixer/*
```

**Prevention:**
- Add disk space monitoring
- Set up cron cleanup
- Consider shorter retention period during high load

## Security Considerations

1. **Automatic deletion** - Files are not kept indefinitely
2. **Unique filenames** - UUIDs prevent filename conflicts
3. **Isolated storage** - Separate temp directory per application
4. **No permanent storage** - Files never stored permanently
5. **Access control** - Job IDs required to download files

## Future Enhancements

Potential improvements:

1. **Database tracking** - Track file ages in database instead of filesystem
2. **User-specific retention** - Different timeouts for registered vs anonymous users
3. **Download counter** - Delete after N downloads or 24 hours, whichever comes first
4. **Cloud storage** - Move to S3/GCS with automatic expiration policies
5. **Configurable per-upload** - Let users choose retention period (1h, 12h, 24h, 48h)
