import { createTheme } from '@mui/material/styles';
import { colorsLight, comp } from './tokens/tokens';

// 通途 MUI 主题：palette 取自 sys 全局 token；Button 尺寸取自 comp（与 Flutter/CSS 同源）。
// 变体色不在此——按 comp 单一入口，由 Button 组件按 variant 从 comp 显式取（见 Button.tsx）。
export const tongtuTheme = createTheme({
  palette: {
    primary: { main: colorsLight.primary, contrastText: colorsLight.onPrimary },
    secondary: { main: colorsLight.secondary, contrastText: colorsLight.onSecondary },
    background: { default: colorsLight.background, paper: colorsLight.surface },
    text: { primary: colorsLight.onSurface, secondary: colorsLight.onSurfaceVariant },
    error: { main: colorsLight.error },
    divider: colorsLight.outline,
  },
  components: {
    MuiButton: {
      styleOverrides: {
        // Button 共享尺寸（comp 单一入口）：stadium 圆角、横向内距、最小高度，均取 comp/button/*。
        root: {
          borderRadius: comp.buttonShape,
          paddingLeft: comp.buttonPaddingHorizontal,
          paddingRight: comp.buttonPaddingHorizontal,
          minHeight: comp.buttonContainerHeight,
          textTransform: 'none',
        },
      },
    },
  },
});
