import CssBaseline from '@mui/material/CssBaseline';
import Stack from '@mui/material/Stack';
import Typography from '@mui/material/Typography';
import { ThemeProvider } from '@mui/material/styles';
import { tongtuTheme } from './theme';
import { TongtuButton, type TongtuButtonVariant } from './Button';

const VARIANTS: TongtuButtonVariant[] = ['filled', 'tonal', 'outlined', 'text', 'elevated'];

// 冒烟页：渲染 Button 各变体（enabled / disabled）。
export default function App() {
  return (
    <ThemeProvider theme={tongtuTheme}>
      <CssBaseline />
      <Stack spacing={2} sx={{ p: 4 }}>
        <Typography variant="h5">通途 Web 组件库 · Button</Typography>
        {VARIANTS.map((v) => (
          <Stack key={v} direction="row" spacing={2} alignItems="center">
            <TongtuButton variant={v} onClick={() => {}}>
              {v}
            </TongtuButton>
            <TongtuButton variant={v} disabled>
              {v}
            </TongtuButton>
          </Stack>
        ))}
      </Stack>
    </ThemeProvider>
  );
}
