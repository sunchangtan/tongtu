import { createTheme } from '@mui/material/styles';
import { colorsLight, dims } from '../tokens/tokens';

// 通途 MUI 主题：palette + Button 样式全部取自跨栈 token（与 Flutter/CSS 同源）。
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
        // Button 样式集中（对应 Flutter component themes）：stadium 圆角、横向内距、不全大写。
        root: {
          borderRadius: dims.radiusFull,
          paddingLeft: dims.spaceXl,
          paddingRight: dims.spaceXl,
          minHeight: 40,
          textTransform: 'none',
        },
      },
    },
  },
});
