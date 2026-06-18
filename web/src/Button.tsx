import MuiButton from '@mui/material/Button';
import type { ReactNode } from 'react';
import type { SxProps, Theme } from '@mui/material/styles';
import { compColorsLight as c } from '../tokens/tokens';

/// 通途 Button 变体（中性命名，与 Figma/Flutter 同一契约）。见 docs/design/component-contract.md。
export type TongtuButtonVariant = 'filled' | 'tonal' | 'outlined' | 'text' | 'elevated';

// 中性 variant → MUI variant；tonal/elevated MUI 无原生，用 contained + sx 自定义。
const MUI_VARIANT: Record<TongtuButtonVariant, 'contained' | 'outlined' | 'text'> = {
  filled: 'contained',
  tonal: 'contained',
  outlined: 'outlined',
  text: 'text',
  elevated: 'contained',
};

// comp 单一入口：各变体颜色（含 disabled）只读 comp/button/*（compColorsLight），不依赖 MUI palette 默认。
function variantSx(variant: TongtuButtonVariant): SxProps<Theme> {
  switch (variant) {
    case 'filled':
      return {
        backgroundColor: c.buttonFilledContainerColor,
        color: c.buttonFilledLabelColor,
        '&:hover': { backgroundColor: c.buttonFilledContainerColor },
        '&.Mui-disabled': {
          backgroundColor: c.buttonDisabledContainer,
          color: c.buttonDisabledLabel,
        },
      };
    case 'tonal':
      return {
        backgroundColor: c.buttonTonalContainerColor,
        color: c.buttonTonalLabelColor,
        boxShadow: 'none',
        '&:hover': { backgroundColor: c.buttonTonalContainerColor, boxShadow: 'none' },
        '&.Mui-disabled': {
          backgroundColor: c.buttonDisabledContainer,
          color: c.buttonDisabledLabel,
        },
      };
    case 'outlined':
      return {
        color: c.buttonOutlinedLabelColor,
        borderColor: c.buttonOutlinedOutlineColor,
        '&:hover': { borderColor: c.buttonOutlinedOutlineColor },
        '&.Mui-disabled': {
          color: c.buttonDisabledLabel,
          borderColor: c.buttonDisabledOutline,
        },
      };
    case 'text':
      return {
        color: c.buttonTextLabelColor,
        '&.Mui-disabled': { color: c.buttonDisabledLabel },
      };
    case 'elevated':
      return {
        backgroundColor: c.buttonElevatedContainerColor,
        color: c.buttonElevatedLabelColor,
        '&.Mui-disabled': {
          backgroundColor: c.buttonDisabledContainer,
          color: c.buttonDisabledLabel,
        },
      };
  }
}

export interface TongtuButtonProps {
  variant: TongtuButtonVariant;
  children: ReactNode;
  onClick?: () => void;
  startIcon?: ReactNode;
  disabled?: boolean;
}

export function TongtuButton({ variant, children, onClick, startIcon, disabled }: TongtuButtonProps) {
  return (
    <MuiButton
      variant={MUI_VARIANT[variant]}
      onClick={onClick}
      startIcon={startIcon}
      disabled={disabled}
      disableElevation={variant !== 'elevated'}
      sx={variantSx(variant)}
    >
      {children}
    </MuiButton>
  );
}
