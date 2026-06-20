import CssBaseline from '@mui/material/CssBaseline';
import Box from '@mui/material/Box';
import Stack from '@mui/material/Stack';
import Typography from '@mui/material/Typography';
import { ThemeProvider } from '@mui/material/styles';
// 组件 / 主题 / token 全部经组件库包入口取（workspace 依赖 @tongtu/components），不再相对路径深引。
import { tongtuTheme, TongtuButton, type TongtuButtonVariant, comp } from '@tongtu/components';
import { Icon, iconsData, type IconName } from '@tongtu/icons';

const VARIANTS: TongtuButtonVariant[] = ['filled', 'tonal', 'outlined', 'text', 'elevated'];

const STATES: { label: string; disabled: boolean; icon: boolean }[] = [
  { label: '默认', disabled: false, icon: false },
  { label: '带图标', disabled: false, icon: true },
  { label: '禁用', disabled: true, icon: false },
  { label: '禁用 + 图标', disabled: true, icon: true },
];

// 前置图标占位：圆点（对应 Figma 设计稿的 ELLIPSE 图标位）。
// 尺寸取 comp/button/icon-size，颜色用 currentColor 自动跟随按钮前景（含 disabled 灰）。
function Dot() {
  return (
    <Box
      component="span"
      sx={{
        width: comp.buttonIconSize,
        height: comp.buttonIconSize,
        borderRadius: '50%',
        bgcolor: 'currentColor',
        display: 'inline-block',
      }}
    />
  );
}

// 组件库展示页：对齐 Figma 设计稿 20 变体（5 variant × enabled/disabled × 无图标/前置图标）。
// 响应式：每变体一组，组内按钮 flex-wrap——宽屏成行、窄屏自动换行，label 统一「Button」。
export default function App() {
  return (
    <ThemeProvider theme={tongtuTheme}>
      <CssBaseline />
      <Box sx={{ p: { xs: 2, sm: 4 }, maxWidth: 960, mx: 'auto' }}>
        <Typography variant="h5" gutterBottom>
          通途 Web 组件库 · Button
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
          5 变体 × enabled / disabled × 无图标 / 前置图标，对齐 Figma 设计稿（共 20 态）。
        </Typography>

        <Stack spacing={{ xs: 3, sm: 4 }}>
          {VARIANTS.map((v) => (
            <Box key={v}>
              <Typography variant="subtitle2" sx={{ mb: 1.5, fontWeight: 600 }}>
                {v}
              </Typography>
              <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: { xs: 2, sm: 3 } }}>
                {STATES.map((s) => (
                  <Stack
                    key={s.label}
                    spacing={0.75}
                    alignItems="flex-start"
                    sx={{ minWidth: 128 }}
                  >
                    <TongtuButton
                      variant={v}
                      onClick={() => {}}
                      disabled={s.disabled}
                      startIcon={s.icon ? <Dot /> : undefined}
                    >
                      Button
                    </TongtuButton>
                    <Typography variant="caption" color="text.secondary">
                      {s.label}
                    </Typography>
                  </Stack>
                ))}
              </Box>
            </Box>
          ))}
        </Stack>

        <Typography variant="h5" gutterBottom sx={{ mt: 6 }}>
          通途图标库 · Icons
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
          {Object.keys(iconsData).length} 个 Lucide 图标（与 Flutter / Figma 同源，描边随 currentColor）。
        </Typography>
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(92px, 1fr))',
            gap: 1.5,
          }}
        >
          {(Object.keys(iconsData) as IconName[]).map((name) => (
            <Stack
              key={name}
              spacing={1}
              alignItems="center"
              sx={{ p: 1.5, border: '1px solid', borderColor: 'divider', borderRadius: 2 }}
            >
              <Icon name={name} size={24} />
              <Typography
                variant="caption"
                color="text.secondary"
                sx={{ fontSize: 11, textAlign: 'center', lineHeight: 1.3, wordBreak: 'break-word' }}
              >
                {name}
              </Typography>
            </Stack>
          ))}
        </Box>
      </Box>
    </ThemeProvider>
  );
}
