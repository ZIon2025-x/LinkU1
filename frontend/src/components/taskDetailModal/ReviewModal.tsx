import React from 'react';

interface ReviewModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: () => Promise<void>;
  reviewRating: number;
  setReviewRating: (rating: number) => void;
  hoverRating: number;
  setHoverRating: (rating: number) => void;
  reviewComment: string;
  setReviewComment: (comment: string) => void;
  isAnonymous: boolean;
  setIsAnonymous: (anonymous: boolean) => void;
  actionLoading: boolean;
  t: (key: string) => string;
}

const ReviewModal: React.FC<ReviewModalProps> = ({
  isOpen,
  onClose,
  onSubmit,
  reviewRating,
  setReviewRating,
  hoverRating,
  setHoverRating,
  reviewComment,
  setReviewComment,
  isAnonymous,
  setIsAnonymous,
  actionLoading,
  t
}) => {
  if (!isOpen) return null;

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: 'rgba(0,0,0,0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1001
    }}>
      <div style={{
        background: '#fff',
        borderRadius: 16,
        padding: 32,
        maxWidth: 500,
        width: '90%',
        maxHeight: '80vh',
        overflow: 'auto'
      }}>
        <h2 style={{marginBottom: 24, color: '#A67C52', textAlign: 'center'}}>
          {t('taskDetail.reviewModal.title')}
        </h2>
        
        <div style={{marginBottom: 20}}>
          <label style={{display: 'block', marginBottom: 8, fontWeight: 600, color: '#333'}}>
            {t('taskDetail.reviewModal.ratingLabel')}
          </label>
          <div style={{display: 'flex', gap: 4, justifyContent: 'center', alignItems: 'center'}}>
            {[0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5].map(star => (
              <button
                key={star}
                onClick={() => setReviewRating(star)}
                onMouseEnter={() => setHoverRating(star)}
                onMouseLeave={() => setHoverRating(0)}
                style={{
                  background: 'none',
                  border: 'none',
                  fontSize: star % 1 === 0 ? 24 : 18,
                  cursor: 'pointer',
                  color: star <= (hoverRating || reviewRating) ? '#ffc107' : '#ddd',
                  transition: 'all 0.3s ease',
                  padding: '2px',
                  transform: star <= (hoverRating || reviewRating) ? 'scale(1.2)' : 'scale(1)',
                  filter: star <= (hoverRating || reviewRating) ? 'drop-shadow(0 0 8px rgba(255, 193, 7, 0.6))' : 'none'
                }}
              >
                {star <= (hoverRating || reviewRating) ? '⭐' : '☆'}
              </button>
            ))}
          </div>
          <div style={{
            textAlign: 'center', 
            marginTop: 8, 
            color: '#666', 
            fontSize: 14,
            fontWeight: 600,
            opacity: reviewRating > 0 ? 1 : 0.7,
            transform: reviewRating > 0 ? 'scale(1.05)' : 'scale(1)',
            transition: 'all 0.3s ease'
          }}>
            {t('taskDetail.reviewModal.currentRating').replace('{rating}', reviewRating.toString())}
          </div>
        </div>

        <div style={{marginBottom: 24}}>
          <label style={{display: 'block', marginBottom: 8, fontWeight: 600, color: '#333'}}>
            {t('taskDetail.reviewModal.commentLabel')}
          </label>
          <textarea
            value={reviewComment}
            onChange={(e) => setReviewComment(e.target.value)}
            placeholder={t('taskDetail.reviewModal.commentPlaceholder')}
            style={{
              width: '100%',
              minHeight: 100,
              padding: 12,
              border: '1px solid #ddd',
              borderRadius: 8,
              fontSize: 14,
              resize: 'vertical'
            }}
          />
        </div>

        <div style={{marginBottom: 24}}>
          <label style={{display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer'}}>
            <input
              type="checkbox"
              checked={isAnonymous}
              onChange={(e) => setIsAnonymous(e.target.checked)}
              style={{transform: 'scale(1.2)'}}
            />
            <span style={{fontWeight: 600, color: '#333'}}>
              {t('taskDetail.reviewModal.anonymousLabel')}
            </span>
            <span style={{fontSize: 12, color: '#666'}}>
              {t('taskDetail.reviewModal.anonymousNote')}
            </span>
          </label>
        </div>

        <div style={{display: 'flex', gap: 12, justifyContent: 'center'}}>
          <button
            onClick={onSubmit}
            disabled={actionLoading}
            style={{
              background: '#28a745',
              color: '#fff',
              border: 'none',
              borderRadius: 8,
              padding: '12px 24px',
              fontWeight: 600,
              fontSize: 16,
              cursor: actionLoading ? 'not-allowed' : 'pointer',
              opacity: actionLoading ? 0.6 : 1
            }}
          >
            {actionLoading ? t('taskDetail.reviewModal.submitting') : t('taskDetail.reviewModal.submit')}
          </button>
          <button
            onClick={onClose}
            style={{
              background: '#6c757d',
              color: '#fff',
              border: 'none',
              borderRadius: 8,
              padding: '12px 24px',
              fontWeight: 600,
              fontSize: 16,
              cursor: 'pointer'
            }}
          >
            {t('taskDetail.reviewModal.cancel')}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ReviewModal;


