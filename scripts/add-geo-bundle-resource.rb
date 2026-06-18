#!/usr/bin/env ruby
# 把 geo 预置包 BundleMRS.7z（资源）与 GeoBundleInstaller.swift（源）加入 Flutter 的
# ios/Runner.xcodeproj 的 Runner target（change p1-geo-mrs-conversion 任务 3.3/4.1）。
#
# 为什么用脚本：Flutter 默认只管 AppDelegate 等少数源，手改 pbxproj 易错；本脚本用 xcodeproj gem
# 幂等地把新源/资源加入 Runner target，pbxproj 入库。运行：ruby scripts/add-geo-bundle-resource.rb
# 前置：ios/Runner/Resources/BundleMRS.7z 须已由 scripts/build-geo-bundle.sh 生成。
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'ios', 'Runner.xcodeproj')

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target 未找到' unless runner
runner_group = project.main_group['Runner']
raise 'Runner group 未找到' unless runner_group

# 1. GeoBundleInstaller.swift → Runner source build phase（幂等）
swift_name = 'GeoBundleInstaller.swift'
src_refs = runner.source_build_phase.files_references.compact
unless src_refs.any? { |f| f.display_name == swift_name }
  ref = runner_group.new_reference(swift_name)
  runner.source_build_phase.add_file_reference(ref)
  raise "源文件路径错误: #{ref.real_path}" unless File.exist?(ref.real_path)
  puts "✓ 加 source: #{swift_name} → #{ref.real_path}"
end

# 2. BundleMRS.7z → Runner resources build phase（幂等）
res_name = 'BundleMRS.7z'
res_refs = runner.resources_build_phase.files_references.compact
unless res_refs.any? { |f| f.display_name == res_name }
  res_group = runner_group['Resources'] || runner_group.new_group('Resources', 'Resources')
  ref = res_group.new_reference(res_name)
  raise "资源路径错误: #{ref.real_path}（需先跑 build-geo-bundle.sh）" unless File.exist?(ref.real_path)
  runner.resources_build_phase.add_file_reference(ref)
  puts "✓ 加 resource: #{res_name} → #{ref.real_path}"
end

project.save
puts '✓ 完成（ios/Runner.xcodeproj/project.pbxproj 已更新）'
