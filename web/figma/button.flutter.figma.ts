import figma, { html } from '@figma/code-connect/html';

// Flutter 无官方 Code Connect 集成（已查证，见 design D9）→ 用 html template（框架无关）
// 输出 Flutter 代码片段。发布用 --parser html，见 web/CODE_CONNECT.md。
figma.connect(
  'https://www.figma.com/design/7Lt4B6C58u9HoTCvUKNUGR/Tongtu-Brand?node-id=132-52',
  {
    // Flutter html template 无组件 import → CLI 推断不出 source（View connection 跳不了）；
    // 用 links 显式给一个跳到 Flutter 组件源码的链接，弥补 View connection。
    links: [
      {
        name: 'Flutter 组件源码',
        url: 'https://github.com/sunchangtan/tongtu/blob/main/lib/ui/components/button.dart',
      },
    ],
    props: {
      variant: figma.enum('Variant', {
        filled: 'filled',
        tonal: 'tonal',
        outlined: 'outlined',
        text: 'text',
        elevated: 'elevated',
      }),
      // State → onPressed（含尾逗号）：enabled 给 callback、disabled 为 null + 注释明示
      //（Flutter 惯例：onPressed 为 null 即禁用，组件无 disabled 参数）。占位符不接受三元，故整值经 enum 映射
      onPressed: figma.enum('State', {
        enabled: '() {},',
        disabled: 'null, // 禁用（onPressed 为 null 即禁用）',
      }),
      // Icon 维度 → leadingIcon 整行（leading 显示前置图标行，none 为空；同样规避三元）
      leadingIcon: figma.enum('Icon', {
        leading: '\n  leadingIcon: const Icon(Icons.circle),',
        none: '',
      }),
    },
    example: (props) => html`TongtuButton(
  variant: TongtuButtonVariant.${props.variant},
  onPressed: ${props.onPressed}${props.leadingIcon}
  label: 'Button',
)`,
  },
);
