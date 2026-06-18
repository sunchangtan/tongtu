import figma from '@figma/code-connect';
import { TongtuButton } from './Button';

// Code Connect：Figma Button Component Set → React TongtuButton。
// 发布（需 Figma access token）：见 web/CODE_CONNECT.md。
figma.connect(
  TongtuButton,
  'https://www.figma.com/design/7Lt4B6C58u9HoTCvUKNUGR/Tongtu-Brand?node-id=132-52',
  {
    props: {
      variant: figma.enum('Variant', {
        filled: 'filled',
        tonal: 'tonal',
        outlined: 'outlined',
        text: 'text',
        elevated: 'elevated',
      }),
      disabled: figma.enum('State', { enabled: false, disabled: true }),
      // Icon 维度 → startIcon（leading 显示前置图标，none 不传；圆点占位呼应设计稿）
      startIcon: figma.enum('Icon', { leading: <span>●</span>, none: undefined }),
    },
    example: ({ variant, disabled, startIcon }) => (
      <TongtuButton variant={variant} disabled={disabled} startIcon={startIcon}>
        Button
      </TongtuButton>
    ),
  },
);
