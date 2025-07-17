# rclone-airflow
Rclone + Airflow for scheduled, easily configurable backups & syncs

A Docker-based backup solution that combines Apache Airflow for scheduling with Rclone for data transfer. Perfect for automated backups to cloud storage, NAS, or other destinations.

## 🚀 Quick Start

### Option A: Portainer Deployment (Recommended)

For easy deployment with Portainer:

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url> && cd rclone-airflow
   ```

2. **Run the setup script**:
   ```bash
   ./manage.sh setup
   ```

3. **Configure rclone**:
   ```bash
   ./manage.sh config-rclone
   ```

4. **Edit backup jobs**:
   ```bash
   ./manage.sh edit-jobs
   ```

5. **Deploy via Portainer**:
   - See detailed instructions in [PORTAINER.md](PORTAINER.md)
   - Or deploy locally: `./manage.sh deploy`

### Option B: Traditional Docker Compose

- Have Docker & docker-compose installed
- Clone this repository: `git clone <your-repo-url> && cd rclone-airflow`
- Rclone config:
  - Copy your current config file `~/.config/rclone/rclone.conf` to conf/rclone, or
  - Generate a new one with `docker run --rm -it --user $UID:$GID --volume $PWD/conf/rclone:/config/rclone rclone/rclone config`
- Jobs config: See "Configuration"
- Docker-compose:
  - Regarding compose files:
    - Use prebuilt image with `docker-compose.yml`, or
    - Use locally built image with `docker-compose.local.yml` and add your own DAGs & plugins, build with `AIRFLOW_UID=$UID docker-compose -f docker-compose.local.yml build`
  - Add your data volumes in x-rclone-conf.volumes, preferablly using :rw flag if you're just using this for backups
  - Change TZ to your local timezone, use [TZ database name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) format
- Start the service stack
  - Prebuilt image: `AIRFLOW_UID=$UID docker-compose up -d`
  - Local image: `AIRFLOW_UID=$UID docker-compose -f docker-compose.local.yml up -d`


## 📋 Configuration

### Backup Jobs Configuration

Jobs are configured in `/conf/jobs.yml`. Each job creates a separate Airflow DAG.

```yaml
# Example: Daily home directory backup
home_backup:
  cron: "0 2 * * *"        # Daily at 2 AM (crontab format)
  source: "/data/home"      # Source path
  target: "remote:backups/home"  # Target destination
  backup: "remote:backups/versioned/home"  # Optional: versioned backups
  retries: 3               # Number of retries on failure
  retry_delay_minutes: 10  # Delay between retries
  paused: true            # Start paused (manually enable in Airflow)
  rclone_options:         # Additional rclone options
    progress: true
    transfers: 4

# Example: Weekly database backup
database_backup:
  cron: "0 3 * * 0"       # Weekly on Sunday at 3 AM
  source: "/data/databases"
  target: "s3:my-bucket/database-backups"
  backup: "s3:my-bucket/database-backups/versions"
  rclone_options:
    compress: true
```

### Job Configuration Options

- **cron**: Schedule in crontab format (required) - see [crontab.guru](https://crontab.guru)
- **source**: Source location path (required)
- **target**: Target destination (required)
- **backup**: Optional backup directory for versioned backups
  - Creates timestamped directories like `backup-dir/YYYYMMDD-HHMMSS`
- **retries**: Number of retries on failure (default: 3)
- **retry_delay_minutes**: Minutes to wait between retries (default: 5)
- **paused**: Whether to start the DAG paused (default: true)
- **email_on_failure**: Send email notifications on failure (default: false)
- **catchup**: Whether to run missed schedules (default: false)
- **rclone_options**: Additional rclone command options

### Rclone Remote Configuration

Configure your rclone remotes using:
```bash
./manage.sh config-rclone
```

Or manually:
```bash
docker run --rm -it --volume ./conf/rclone:/config/rclone rclone/rclone config
```

## 🔧 Management

Use the included management script for common tasks:

```bash
# Initial setup
./manage.sh setup

# Configure rclone remotes
./manage.sh config-rclone

# Edit backup jobs
./manage.sh edit-jobs

# Deploy stack
./manage.sh deploy

# View status
./manage.sh status

# View logs
./manage.sh logs airflow-scheduler

# Test rclone connection
./manage.sh test-rclone

# Backup configuration
./manage.sh backup-config
```

## 📊 Web Interfaces

After deployment, access:

- **Airflow Web UI**: http://localhost:8080
  - Username: `admin` (configurable)
  - Password: `admin` (configurable)
  - Enable/disable backup jobs
  - Monitor job status and logs

- **Rclone Web UI**: http://localhost:5572
  - Username: `rclone` (configurable)
  - Password: `rclone` (configurable)
  - Browse remote filesystems
  - Monitor transfer progress

## 🐳 Portainer Deployment

For production deployments using Portainer, see the detailed guide in [PORTAINER.md](PORTAINER.md).

Key benefits of Portainer deployment:
- Easy web-based management
- Environment variable configuration
- Volume management
- Health monitoring
- Automatic restarts
- Log aggregation

## 📈 Monitoring

- **Airflow DAGs**: Monitor backup job status, execution history, and logs
- **Rclone Metrics**: Prometheus-compatible metrics endpoint at `/metrics`
- **Health Checks**: All services include Docker health checks
- **Email Notifications**: Configure SMTP for failure alerts (see `.env.example`)

## 🔒 Security

- Change default passwords in `.env` file
- Use strong Fernet key for Airflow encryption
- Secure rclone configuration with proper authentication
- Limit network access using Docker networks
- Regular updates of container images

## 🚨 Troubleshooting

### Common Issues

1. **Permission Issues**: Ensure `AIRFLOW_UID` matches your host user ID
2. **Rclone Connection**: Verify remote configuration with `./manage.sh test-rclone`
3. **Service Startup**: Check logs with `./manage.sh logs <service>`
4. **Job Failures**: Check Airflow task logs in the web interface

### Getting Help

- Check container logs: `docker logs <container_name>`
- Access Airflow CLI: `docker exec -it <airflow_container> airflow --help`
- Test rclone manually: `docker exec -it <rclone_container> rclone ls remote:`

## 🔄 Backup Strategy

1. **Regular config backups**: Use `./manage.sh backup-config`
2. **Test restores**: Regularly verify your backup integrity
3. **Monitor disk space**: Ensure sufficient space for transfers and logs
4. **Version control**: Keep your `jobs.yml` and configurations in git

## 📚 Additional Resources

- [Rclone Documentation](https://rclone.org/docs/)
- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [Portainer Documentation](https://docs.portainer.io/)
- [Crontab Guru](https://crontab.guru/) - for schedule configuration

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## Components and Dependencies

Using rclone rcd as rclone server, and Airflow + rclonerc to control rclone using HTTP API;

- RClone: pinned to 1.56.2 via compose file, though upgrading shouldn't pose much problems
- Airflow: pinned to 2.2.0, upgrading might need further changes to compose file
- [rclonerc](https://github.com/chenseanxy/rclonerc): Via Dockerfile, not pinned

##  Contributing

This is a POC at the moment, and all issues & pull requests are welcome!

Current ideas:

- Configurable success & error hooks, for notification, etc
- Allow for generic rclone flags, filters, options, etc
- Runnable DAG for global bandwidth limit, etc

Dev environment: use `docker-compose -f docker-compose.local.yml up -d` & `pipenv install --dev`
