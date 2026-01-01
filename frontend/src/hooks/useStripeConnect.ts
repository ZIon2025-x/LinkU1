import { useState, useEffect } from "react";
import { loadConnectAndInitialize } from "@stripe/connect-js";
import api from "../api";

/**
 * Hook for managing Stripe Connect instance
 * Based on stripe-sample-code/hooks/useStripeConnect.js
 */
export const useStripeConnect = (connectedAccountId: string | null | undefined) => {
  const [stripeConnectInstance, setStripeConnectInstance] = useState<any>(null);

  useEffect(() => {
    if (!connectedAccountId) {
      setStripeConnectInstance(null);
      return;
    }

    const fetchClientSecret = async () => {
      try {
        // 参考 stripe-sample-code/server.js 的 /account_session 端点
        const response = await api.post("/api/stripe/connect/account_session", {
          account: connectedAccountId,
        });

        if (!response.data) {
          throw new Error("No data in response");
        }

        const { client_secret: clientSecret, error } = response.data;

        if (error) {
          throw new Error(error);
        }

        if (!clientSecret) {
          throw new Error("No client secret in response");
        }

        return clientSecret;
      } catch (error: any) {
        console.error("Error fetching client secret:", error);
        const errorMessage = error.response?.data?.detail || error.message || "An error occurred";
        
        // 如果是 403 错误（账户不匹配），可能是账户刚创建，需要等待
        if (error.response?.status === 403) {
          console.warn("Account session access denied, account may not be ready yet");
        }
        
        // 如果是 500 错误，可能是 Stripe API 问题或账户未准备好
        if (error.response?.status === 500) {
          console.warn("Server error creating account session, account may not be ready yet");
        }
        
        throw new Error(errorMessage);
      }
    };

    const publishableKey = process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY || 
      (process.env as any).STRIPE_PUBLISHABLE_KEY;

    if (!publishableKey) {
      console.error("STRIPE_PUBLISHABLE_KEY is not set");
      return;
    }

    try {
      const instance = loadConnectAndInitialize({
        publishableKey,
        fetchClientSecret,
        appearance: {
          overlays: "dialog",
          variables: {
            colorPrimary: "#635BFF",
          },
        },
        // 确保使用嵌入式组件，不跳转到外部页面
        // 这些配置确保所有操作都在应用内完成
      });

      setStripeConnectInstance(instance);
    } catch (error) {
      console.error("Error initializing Stripe Connect:", error);
    }
  }, [connectedAccountId]);

  return stripeConnectInstance;
};

export default useStripeConnect;

