/**
 * Stripe 模块类型声明（当 npm 包自带的类型无法被正确解析时的回退）
 * 若 @stripe/* 已正确安装且含 types，可删除本文件
 */
declare module '@stripe/stripe-js' {
  export function loadStripe(publishableKey: string, options?: unknown): Promise<unknown>;
  export interface StripeElementsOptions {
    [key: string]: unknown;
  }
}

declare module '@stripe/react-stripe-js' {
  import { ComponentType } from 'react';
  export const Elements: ComponentType<{ options?: unknown; [k: string]: unknown }>;
  export const PaymentElement: ComponentType<{ [k: string]: unknown }>;
  export function useStripe(): any;
  export function useElements(): any;
}

declare module '@stripe/connect-js' {
  export function loadConnectAndInitialize(options: unknown): Promise<unknown>;
}

declare module '@stripe/react-connect-js' {
  import { ComponentType } from 'react';
  export const ConnectAccountOnboarding: ComponentType<{ [k: string]: unknown }>;
  export const ConnectComponentsProvider: ComponentType<{ [k: string]: unknown }>;
  export const ConnectAccountManagement: ComponentType<{ [k: string]: unknown }>;
  export const ConnectPayouts: ComponentType<{ [k: string]: unknown }>;
  export const ConnectPayments: ComponentType<{ [k: string]: unknown }>;
}
