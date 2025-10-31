require 'xcodeproj'

project_path = 'ExpenseTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到Services组
target = project.targets.first
services_group = project.main_group.find_subpath('ExpenseTracker/Features/AutoRecognition/Services', true)

# 要添加的文件
files_to_add = [
  'ExpenseTracker/Features/AutoRecognition/Services/HybridOCRService.swift',
  'ExpenseTracker/Features/AutoRecognition/Services/MLKitOCRService.swift',
  'ExpenseTracker/Features/AutoRecognition/Services/PaymentReceiptParser.swift',
  'ExpenseTracker/Features/AutoRecognition/Services/ImagePreprocessor.swift'
]

files_to_add.each do |file_path|
  file_ref = services_group.new_reference(file_path)
  target.add_file_references([file_ref])
  puts "Added: #{file_path}"
end

project.save
puts "Project updated successfully!"
