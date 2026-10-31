namespace :webpush do
  desc "Generate a VAPID key pair for web push (put the output in .env / Secrets Manager)"
  task :keys do
    require "web_push"
    key = WebPush.generate_key
    puts "VAPID_PUBLIC_KEY=#{key.public_key}"
    puts "VAPID_PRIVATE_KEY=#{key.private_key}"
  end
end
