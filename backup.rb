require 'fileutils'
require 'time'
require 'aws-sdk-s3'
require 'dotenv/load'  # Add this line to load environment variables from .env

# Configuration
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
    backup_command = "mysqldump -h #{DB_HOST} -P #{DB_PORT} -u #{DB_USERNAME} -p#{DB_PASSWORD} #{DB_NAME} > #{backup_file}"

    if ENV['DEBUG']
        puts "Backup command: #{backup_command}"
    end
     puts "Backup command: #{backup_command}"

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
    
    # Remove the backup file and uncompressed backup file
    File.delete(backup_file)
    File.delete(compressed_backup_file)
    
    puts "Upload to S3 successful"
    else
    puts "Backup failed!"
    end
end

#Call the backup_and_upload method
backup_and_upload()
