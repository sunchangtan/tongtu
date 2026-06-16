#!/usr/bin/env ruby
# 给 Flutter 的 ios/Runner.xcodeproj 加 PacketTunnel NE 扩展 target（change p1-m1-ios-skeleton 任务 2.1/2.3）。
#
# 为什么用脚本：Flutter 不生成 NE 扩展 target，手改 619 行 pbxproj 易错；本脚本用 xcodeproj gem
# 可复现地加 target（幂等：已存在则先移除重建），pbxproj 入库。运行：ruby scripts/add-packet-tunnel-target.rb
#
# 配置要点（对齐 specs/apple-packet-tunnel 与 ios-poc/project.yml）：
#   - app-extension target，bundle com.dingqi.tongtu.packet-tunnel
#   - 源：ios/PacketTunnel/*.swift + ios/Shared/SharedStore.swift（与主 App 共享）
#   - 链接 build/MihomoCore.xcframework（含 gvisor）+ libresolv.tbd（Go DNS 依赖）
#   - 扩展与主 App 各自 entitlements（NE + App Group group.com.dingqi.tongtu）
#   - 主 App 内嵌扩展（Embed App Extensions）并依赖之

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'ios', 'Runner.xcodeproj')
TEAM = 'RSKBV78K2Y'
EXT_NAME = 'PacketTunnel'
EXT_BUNDLE = 'com.dingqi.tongtu.packet-tunnel'

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target 未找到' unless runner

# 与 MihomoCore.xcframework 的最低 iOS 版本（15.0）一致，避免 ld "built for newer iOS version" 链接告警
deployment = '15.0'

# 幂等：移除已存在的同名 target 与 group
project.targets.select { |t| t.name == EXT_NAME }.each(&:remove_from_project)
[EXT_NAME, 'Shared'].each do |gname|
  g = project.main_group[gname]
  g.remove_from_project if g
end

# 新建扩展 target
ext = project.new_target(:app_extension, EXT_NAME, :ios, deployment)
ext.build_configurations.each do |c|
  bs = c.build_settings
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = EXT_BUNDLE
  bs['INFOPLIST_FILE'] = 'PacketTunnel/Info.plist'
  bs['CODE_SIGN_ENTITLEMENTS'] = 'PacketTunnel/PacketTunnel.entitlements'
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = TEAM
  bs['SWIFT_VERSION'] = '5.0'
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = deployment
  bs['FRAMEWORK_SEARCH_PATHS'] = ['$(inherited)', '$(PROJECT_DIR)/../build']
  bs['PRODUCT_NAME'] = '$(TARGET_NAME)'
end

# 源文件组与引用
ext_group = project.main_group.new_group(EXT_NAME, 'PacketTunnel')
shared_group = project.main_group.new_group('Shared', 'Shared')
ext_files = %w[PacketTunnelProvider.swift TunFD.swift InterfaceMonitor.swift ProcessMemory.swift]
              .map { |f| ext_group.new_reference(f) }
shared_ref = shared_group.new_reference('SharedStore.swift')
ext.add_file_references(ext_files + [shared_ref])

# 链接 mihomo 内核 xcframework + libresolv
fw_ref = project.frameworks_group.new_reference('../build/MihomoCore.xcframework')
ext.frameworks_build_phase.add_file_reference(fw_ref)
libresolv = project.frameworks_group.new_reference('usr/lib/libresolv.tbd')
libresolv.source_tree = 'SDKROOT'
ext.frameworks_build_phase.add_file_reference(libresolv)

# 主 App：共享 SharedStore、设置 entitlements、内嵌扩展并依赖之
runner.add_file_references([shared_ref])
runner.build_configurations.each { |c| c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements' }
embed = runner.copy_files_build_phases.find { |p| p.symbol_dst_subfolder_spec == :plug_ins }
embed ||= runner.new_copy_files_build_phase('Embed App Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(ext.product_reference)
# Runner 含 Flutter 注入的依赖项（target 可能为 nil），xcodeproj 的 add_dependency 遍历时会崩；
# embed 阶段已引用扩展产物，Xcode 据此自动推断构建顺序，故显式依赖失败可安全跳过。
begin
  runner.add_dependency(ext)
rescue StandardError => e
  warn "提示：add_dependency 跳过（#{e.message}）；构建顺序由 embed 阶段保证"
end

project.save
puts "✓ 已加入 #{EXT_NAME} target（bundle #{EXT_BUNDLE}，deployment #{deployment}）"
