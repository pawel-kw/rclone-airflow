# Portainer Deployment Guide

This guide will help you deploy the Rclone-Airflow backup system using Portainer.

## Prerequisites

- Portainer CE/EE installed and running
- Docker Swarm mode enabled (for some features) or Docker Compose support
- Access to Portainer web interface

## Quick Deployment

### Step 1: Prepare Configuration

1. **Clone or download this repository** to get the configuration files
2. **Configure your backup jobs** in `conf/jobs.yml` (see example configurations)
3. **Set up rclone configuration**:
   - Create your rclone config using: `rclone config`
   - Copy the config to where Portainer can access it

### Step 2: Deploy Stack in Portainer

1. **Log into Portainer**
2. **Navigate to Stacks**
3. **Create a new stack**:
   - Name: `rclone-airflow-backup`
   - Build method: `Web editor` or `Git repository`

#### Option A: Web Editor

1. Copy the contents of `docker-compose.portainer.yml`
2. Paste into the web editor
3. Configure environment variables (see Environment Variables section below)

#### Option B: Git Repository

1. Use Git repository method
2. Repository URL: `https://github.com/your-username/rclone-airflow`
3. Compose path: `docker-compose.portainer.yml`
4. Configure environment variables

### Step 3: Configure Environment Variables

In Portainer's environment variables section, add:

```bash
# Required Variables
TIMEZONE=America/New_York
AIRFLOW_UID=50000
AIRFLOW_WWW_USER_USERNAME=admin
AIRFLOW_WWW_USER_PASSWORD=your-secure-password
RCLONE_USERNAME=rclone
RCLONE_PASSWORD=your-rclone-password

# Optional - Custom ports
AIRFLOW_WEBSERVER_PORT=8080
RCLONE_WEB_PORT=5572

# Optional - Fernet key for encryption (generate with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
AIRFLOW_FERNET_KEY=your-fernet-key-here
```

### Step 4: Configure Volumes

Before deploying, you need to set up your data volumes. Edit the rclone service volumes section in the compose file:

```yaml
volumes:
  - rclone_config:/config/rclone
  # Add your backup source paths here:
  - /host/path/to/backup:/data/backup:ro
  - /var/lib/docker/volumes:/data/docker-volumes:ro
  - /home:/data/home:ro
  # Add more as needed
```

### Step 5: Deploy

1. Click **Deploy the stack**
2. Wait for all services to start (this may take a few minutes)
3. Check the logs for any errors

## Post-Deployment Configuration

### 1. Access Airflow Web Interface

- URL: `http://your-server:8080`
- Username: `admin` (or what you set in environment variables)
- Password: `admin` (or what you set in environment variables)

### 2. Configure Rclone

You have several options to configure rclone:

#### Option A: Use Portainer Console

1. Go to **Containers** in Portainer
2. Find the `rclone-server` container
3. Click **Console** → **Connect** → `/bin/sh`
4. Run: `rclone config`

#### Option B: Use Docker Command Line

```bash
# Access the rclone container
docker exec -it $(docker ps -q -f name=rclone) /bin/sh

# Run rclone config
rclone config
```

#### Option C: Copy Existing Config

If you have an existing rclone config:

```bash
# Copy your config to the Docker volume
docker cp ~/.config/rclone/rclone.conf $(docker ps -q -f name=rclone):/config/rclone/
```

### 3. Configure Backup Jobs

1. **Edit the jobs configuration**:
   - In Portainer, go to **Volumes**
   - Find `backup_jobs_config` volume
   - You can mount this volume to a temporary container to edit files

2. **Example: Edit jobs via temporary container**:
   ```bash
   # Create temporary container to edit config
   docker run --rm -it -v rclone-airflow-backup_backup_jobs_config:/config alpine sh

   # Install editor
   apk add nano

   # Edit jobs file
   nano /config/jobs.yml
   ```

3. **Configure your backup jobs** (see `conf/jobs.yml` for examples)

### 4. Enable Backup DAGs

1. Go to Airflow web interface
2. Navigate to **DAGs**
3. Find your backup jobs (they'll be named `backup_<job_name>`)
4. Toggle them **ON** to enable scheduling

## Monitoring and Maintenance

### View Logs

In Portainer:
1. Go to **Containers**
2. Click on any container
3. Go to **Logs** tab

### Rclone Web Interface

- URL: `http://your-server:5572`
- Username: `rclone` (or what you set)
- Password: `rclone` (or what you set)

### Backup Job Monitoring

- Check **Airflow → DAGs** for job status
- View **Airflow → Browse → Task Instances** for detailed logs
- Use **Airflow → Admin → Variables** to store configuration

### Health Checks

All services include health checks. In Portainer, unhealthy containers will be marked in red.

## Troubleshooting

### Common Issues

1. **Services won't start**:
   - Check environment variables
   - Verify volume mounts exist
   - Check logs for specific error messages

2. **Rclone connection errors**:
   - Verify rclone configuration
   - Check network connectivity
   - Ensure rclone server is running

3. **Backup jobs fail**:
   - Check source and target paths
   - Verify rclone remote configuration
   - Check Airflow task logs

4. **Permission issues**:
   - Verify `AIRFLOW_UID` matches your host user
   - Check volume mount permissions

### Getting Help

1. **Check container logs**:
   ```bash
   docker logs <container_name>
   ```

2. **Access Airflow CLI**:
   ```bash
   docker exec -it <airflow_container> airflow --help
   ```

3. **Test rclone manually**:
   ```bash
   docker exec -it <rclone_container> rclone ls remote:
   ```

## Security Considerations

1. **Change default passwords** for Airflow and Rclone
2. **Use strong Fernet key** for Airflow encryption
3. **Secure rclone configuration** with proper authentication
4. **Limit network access** using Docker networks
5. **Regular updates** of container images
6. **Backup your configurations** including rclone config and jobs.yml

## Scaling and Performance

- **Worker scaling**: Increase replicas of `airflow-worker` service
- **Resource limits**: Add CPU and memory limits to services
- **Storage**: Use fast storage for PostgreSQL and logs
- **Network**: Ensure sufficient bandwidth for large transfers

## Backup Strategy

1. **Regular config backups**: Backup your `jobs.yml` and rclone config
2. **Database backups**: Consider backing up the PostgreSQL database
3. **Test restores**: Regularly test your backup and restore procedures
4. **Monitor disk space**: Ensure sufficient space for logs and temporary files
