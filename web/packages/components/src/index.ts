// 通途 Web 组件库统一导出入口（@tongtu/components）。
// 消费方（如 apps/playground）只经此入口取组件 / 主题 / token，不深引内部模块路径。
export { TongtuButton } from './Button';
export type { TongtuButtonVariant, TongtuButtonProps } from './Button';
export { tongtuTheme } from './theme';
// 跨栈 token（与 Flutter / CSS 同源的生成物）——供消费方按需取 comp / sys 值。
export * from './tokens/tokens';
