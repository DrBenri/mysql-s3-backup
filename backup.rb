require 'fileutils'
require 'time'
require 'aws-sdk-s3'
require 'dotenv/load'  # Load environment variables from .env

# Configuration
DB_CONNECTION = ENV['BACKUP_DATABASE_CONNECTION']
DB_HOST = ENV['BACKUP_DATABASE_HOST']
DB_PORT = ENV['BACKUP_DATABASE_PORT']
DB_USERNAME = ENV['BACKUP_DATABASE_USER']
DB_PASSWORD = ENV['BACKUP_DATABASE_PASSWORD']
DB_NAME = ENV['BACKUP_DATABASE_NAME']
S3_BUCKET = ENV['AWS_S3_BUCKET']
AWS_REGION = ENV['AWS_S3_REGION']
BACKUP_DIR = 'backups'

def backup_and_upload
  # Ensure backup directory exists
  FileUtils.mkdir_p(BACKUP_DIR)

  # Generate timestamp
  timestamp = Time.now.strftime('%Y%m%d%H%M%S')
  backup_file = File.join(BACKUP_DIR, "backup_#{timestamp}.sql")

  # Command to backup the database
  backup_command = if DB_CONNECTION.nil?
                     "mysqldump -h #{DB_HOST} -P #{DB_PORT} -u #{DB_USERNAME} -p#{DB_PASSWORD} #{DB_NAME} > #{backup_file}"
                   else
                     "mysqldump #{DB_CONNECTION} > #{backup_file}"
                   end

  puts "Backup command: #{backup_command}" if ENV['DEBUG']

  # Execute the backup command
  system(backup_command)

  if $?.exitstatus == 0
    puts "Backup successful: #{backup_file}"

    # Compress the backup file
    compressed_backup_file = "#{backup_file}.gz"
    system("gzip -c #{backup_file} > #{compressed_backup_file}")

    # Upload to S3
    s3_client = Aws::S3::Client.new(region: AWS_REGION)
    s3_client.put_object(bucket: S3_BUCKET, key: "backups/#{File.basename(compressed_backup_file)}", body: File.read(compressed_backup_file))

    # Remove the backup file and compressed backup file
    File.delete(backup_file)
    File.delete(compressed_backup_file)

    puts "Upload to S3 successful"
  else
    puts "Backup failed!"
  end
end

def cleanup
  max_backups = 7

  # Initialize S3 client
  s3_client = Aws::S3::Client.new(region: AWS_REGION)

  # List all backups in S3
  objects = s3_client.list_objects_v2(bucket: S3_BUCKET, prefix: 'backups/').contents

  # Sort objects by last modified date
  backups = objects.sort_by(&:last_modified)

  # Delete old backups if more than max_backups
  if backups.size > max_backups
    backups_to_delete = backups[0...(backups.size - max_backups)]
    backups_to_delete.each do |backup|
      puts "Deleting old backup: #{backup.key}"
      s3_client.delete_object(bucket: S3_BUCKET, key: backup.key)
      puts "Deleted old backup: #{backup.key}"
    end
  else
    puts "No old backups to delete."
  end
end

# Call the backup_and_upload method - will backup every 24 hours
backup_and_upload()

# Call the cleanup method to keep only the last 7 backups in S3
cleanup()
