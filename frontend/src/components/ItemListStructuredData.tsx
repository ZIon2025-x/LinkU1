import type React from 'react';

interface ListItemInput {
  id: number | string;
  url: string;
  name: string;
}

interface ItemListStructuredDataProps {
  items: ListItemInput[];
  listUrl: string;
  listName: string;
  numberOfItems?: number;
}

/**
 * ItemList 结构化数据 - 用于任务列表、论坛列表、跳蚤市场列表等
 * 帮助搜索引擎理解列表页内容，提升富媒体展示
 */
const ItemListStructuredData: React.FC<ItemListStructuredDataProps> = ({
  items,
  listUrl,
  listName,
  numberOfItems
}) => {
  if (!items || items.length === 0) return null;

  const itemListElement = items.slice(0, 20).map((item, index) => ({
    '@type': 'ListItem',
    position: index + 1,
    url: item.url.startsWith('http') ? item.url : `https://www.link2ur.com${item.url}`,
    name: item.name
  }));

  const structuredData = {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    name: listName,
    url: listUrl.startsWith('http') ? listUrl : `https://www.link2ur.com${listUrl}`,
    numberOfItems: numberOfItems ?? items.length,
    itemListElement
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
    />
  );
};

export default ItemListStructuredData;
