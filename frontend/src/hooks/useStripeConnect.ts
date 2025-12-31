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
      });

      setStripeConnectInstance(instance);
    } catch (error) {
      console.error("Error initializing Stripe Connect:", error);
    }
  }, [connectedAccountId]);

  return stripeConnectInstance;
};

export default useStripeConnect;

