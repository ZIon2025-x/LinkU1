import React from 'react';

interface FleaMarketStructuredDataProps {
  item: {
    id: number;
    title: string;
    description: string;
    price: number;
    images: string[];
    location: string;
    category: string;
    created_at: string;
  };
  language: string;
}

const FleaMarketStructuredData: React.FC<FleaMarketStructuredDataProps> = ({ item, language }) => {
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "Product",
    "name": item.title,
    "description": item.description,
    "image": item.images.map(img => 
      img.startsWith('http') ? img : `https://www.link2ur.com${img}`
    ),
    "url": `https://www.link2ur.com/${language}/flea-market/${item.id}`, // 新增：商品URL
    "sku": `FM-${item.id}`,  // 商品SKU（提升富媒体展示概率）
    "mpn": `FM-${item.id}`,  // 制造商零件号（Google 更喜欢同时有 mpn 和 sku）
    "offers": {
      "@type": "Offer",
      "price": item.price,
      "priceCurrency": "GBP",
      "itemCondition": "https://schema.org/UsedCondition", // 新增：商品状态（二手）
      "availability": "https://schema.org/InStock"
    },
    "category": item.category,
    "brand": {
      "@type": "Brand",
      "name": "Link²Ur"
    }
  };

  // 移除 undefined 字段
  const cleanedData = JSON.parse(JSON.stringify(structuredData));

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(cleanedData, null, 2) }}
    />
  );
};

export default FleaMarketStructuredData;

