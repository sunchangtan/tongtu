import figma, { html } from '@figma/code-connect/html';

// Flutter 无官方 Code Connect 集成（已查证，见 design D9）→ 用 html template（框架无关）
// 输出 Flutter 代码片段。发布用 --parser html，见 web/CODE_CONNECT.md。
figma.connect(
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
    },
    example: (props) => html`TongtuButton(
  variant: TongtuButtonVariant.${props.variant},
  onPressed: ${props.disabled ? 'null' : '() {}'},
  label: 'Button',
)`,
  },
);
