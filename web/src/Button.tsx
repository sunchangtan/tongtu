import MuiButton from '@mui/material/Button';
import type { ReactNode } from 'react';
import type { SxProps, Theme } from '@mui/material/styles';
import { colorsLight } from '../tokens/tokens';

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

function customSx(variant: TongtuButtonVariant): SxProps<Theme> | undefined {
  if (variant === 'tonal') {
    return {
      backgroundColor: colorsLight.secondaryContainer,
      color: colorsLight.onSecondaryContainer,
      boxShadow: 'none',
      '&:hover': { backgroundColor: colorsLight.secondaryContainer, boxShadow: 'none' },
    };
  }
  if (variant === 'elevated') {
    return { backgroundColor: colorsLight.surface, color: colorsLight.primary };
  }
  return undefined;
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
      sx={customSx(variant)}
    >
      {children}
    </MuiButton>
  );
}
