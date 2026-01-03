import { useState, useEffect } from "react";
import { useAccount } from "./AccountProvider";

const useAccountStatus = () => {
  const [accountStatus, setAccountStatus] = useState(null);
  const { accountId, setAccountId } = useAccount();

  const fetchAccountStatus = async () => {
    if (!accountId) {
      return;
    }

    try {
      const response = await fetch(`/api/account-status/${accountId}`);
      if (!response.ok) {
        throw new Error("Failed to fetch account status");
      }
      const data = await response.json();
      setAccountStatus(data);
    } catch (error) {
      console.error("Error fetching account status:", error);
      setAccountId(null);
    }
  };

  useEffect(() => {
    // Fetch immediately on mount or accountId change
    fetchAccountStatus();

    // Set up interval to fetch every 5 seconds
    const intervalId = setInterval(fetchAccountStatus, 5000);

    // Clean up interval on unmount or when accountId changes
    return () => clearInterval(intervalId);
  }, [accountId, setAccountId]);

  return {
    accountStatus,
    refreshStatus: fetchAccountStatus,
    needsOnboarding:
      !accountStatus?.chargesEnabled && !accountStatus?.detailsSubmitted,
  };
};

export default useAccountStatus;