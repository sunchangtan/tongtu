import { iconsData, type IconName } from './icons-data';

export type { IconName };

export interface IconProps {
  name: IconName;
  size?: number;
  color?: string;
  strokeWidth?: number;
}

// 通途图标组件（Lucide 描边图标，与 Flutter TongtuIcons / Figma Icons/* 同源）。
// 描边色随 color（默认 currentColor 跟随文本色），尺寸 size，统一 24 viewBox。
export function Icon({ name, size = 24, color = 'currentColor', strokeWidth = 2 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke={color}
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      dangerouslySetInnerHTML={{ __html: iconsData[name] }}
    />
  );
}
