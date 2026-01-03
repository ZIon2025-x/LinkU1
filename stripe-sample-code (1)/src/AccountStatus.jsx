import React from "react";
import { useAccount } from "./AccountProvider";
import useAccountStatus from "./useAccountStatus";

const AccountStatus = ({ onStartOnboarding }) => {
  const { setAccountId } = useAccount();
  const { accountStatus, needsOnboarding } = useAccountStatus();
  if (!accountStatus) {
    return null;
  }

  const statusColor = accountStatus.chargesEnabled ? "green" : "orange";
  const statusText = accountStatus.chargesEnabled ? "Active" : "Pending";

  return (
    <div className="account-status">
      <div className="status-header">
        <h3>
          Account Status:{" "}
          <span style={{ color: statusColor }}>{statusText}</span>
        </h3>
      </div>

      <div className="status-details">
        <div className="status-item">
          <span>Account ID:</span>
          <span>{accountStatus.id}</span>
        </div>
        <div className="status-item">
          <span>Payouts enabled:</span>
          <span>{accountStatus.payoutsEnabled ? "✅" : "❌"}</span>
        </div>
        <div className="status-item">
          <span>Charges enabled:</span>
          <span>{accountStatus.chargesEnabled ? "✅" : "❌"}</span>
        </div>
        <div className="status-item">
          <span>Details submitted:</span>
          <span>{accountStatus.detailsSubmitted ? "✅" : "❌"}</span>
        </div>
      </div>

      {needsOnboarding && (
        <button
          onClick={onStartOnboarding}
          className="button"
          style={{
            marginBottom: "10px",
          }}
        >
          Onboard to collect payments
        </button>
      )}
      <button
        className="button"
        disabled={!accountStatus}
        onClick={() => {
          setAccountId(null);
        }}
      >
        Log out
      </button>
    </div>
  );
};

export default AccountStatus;