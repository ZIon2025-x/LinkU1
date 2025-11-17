# Google Maps 集成开发日志

## 一、需求概述

在LinkU平台中集成Google Maps功能，用于：
1. **任务发布页面**：允许用户通过地图选择或标记任务位置
2. **任务详情页面**：显示任务的具体地理位置
3. **任务列表页面**：在地图上展示任务位置，支持基于地理位置的任务筛选
4. **用户设置**：允许用户设置和更新自己的位置信息

## 一、使用条件和费用说明

### 1.1 使用条件

集成Google Maps需要满足以下条件：

1. **Google Cloud账户**
   - 需要拥有Google账户
   - 在[Google Cloud Console](https://console.cloud.google.com/)创建项目

2. **启用必要的API**
   - Maps JavaScript API（地图显示）
   - Places API（地址自动完成）
   - Geocoding API（地址与坐标转换）

3. **配置结算账户**
   - **重要**：即使使用免费额度，也需要绑定有效的结算账户（信用卡）
   - Google需要验证身份和支付方式，但不会在免费额度内扣费

4. **API密钥**
   - 创建并配置API密钥
   - 设置API密钥限制（推荐）以提高安全性

### 1.2 费用说明

#### 免费额度

**每月200美元的免费使用额度**，适用于所有Google Maps Platform服务。

#### 各API的免费额度（每月）

| API服务 | 免费额度 | 超出后价格 |
|---------|---------|-----------|
| **Maps JavaScript API** | 28,000次地图加载 | $7.00 / 1,000次 |
| **Places API (New)** | 17,000次请求 | $17.00 / 1,000次 |
| **Geocoding API** | 40,000次请求 | $5.00 / 1,000次 |
| **Directions API** | 40,000次请求 | $5.00 / 1,000次 |

**注意**：免费额度是累计的，所有API的使用量都从200美元额度中扣除。

#### 成本估算示例

假设LinkU平台的使用场景：

- **每日活跃用户**: 100人
- **每日任务发布**: 20个（需要地理编码）
- **每日地图查看**: 200次（任务详情、列表）
- **每日地址搜索**: 50次

**月度使用量估算**：
- Maps JavaScript API: 200次/天 × 30天 = 6,000次/月
- Geocoding API: 20次/天 × 30天 = 600次/月
- Places API: 50次/天 × 30天 = 1,500次/月

**成本计算**：
- Maps JavaScript API: 6,000次（免费额度内）
- Geocoding API: 600次（免费额度内）
- Places API: 1,500次（免费额度内）
- **总成本**: $0（在免费额度内）

**结论**：对于中小型应用，200美元的免费额度通常足够使用。

### 1.3 成本控制策略

#### 1. 实施缓存机制

```typescript
// 缓存地理编码结果，避免重复请求
const geocodeCache = new Map<string, { lat: number; lng: number }>();

async function geocodeWithCache(address: string) {
  if (geocodeCache.has(address)) {
    return geocodeCache.get(address);
  }
  
  const result = await geocodeAddress(address);
  if (result) {
    geocodeCache.set(address, result);
  }
  return result;
}
```

#### 2. 限制地图加载频率

```typescript
// 使用防抖，避免频繁加载地图
import { debounce } from 'lodash';

const debouncedMapLoad = debounce((callback) => {
  callback();
}, 300);
```

#### 3. 延迟加载地图

```typescript
// 只在用户需要时加载地图
import { lazy, Suspense } from 'react';

const GoogleMapContainer = lazy(() => import('./GoogleMapContainer'));

// 使用时
<Suspense fallback={<div>加载地图中...</div>}>
  <GoogleMapContainer />
</Suspense>
```

#### 4. 设置使用配额和告警

在Google Cloud Console中：
- 设置每日/每月使用配额限制
- 配置使用量告警（例如：达到免费额度的80%时通知）
- 监控API使用情况

#### 5. 使用静态地图API（可选）

对于简单的显示需求，可以使用[Static Maps API](https://developers.google.com/maps/documentation/maps-static)，它更便宜：
- 免费额度：28,000次/月
- 超出后：$2.00 / 1,000次

### 1.4 替代方案

如果担心成本或无法使用Google Maps，可以考虑：

#### 1. OpenStreetMap + Leaflet（免费）

```bash
npm install react-leaflet leaflet
```

- **优点**：完全免费，开源
- **缺点**：需要自己托管地图瓦片，功能相对简单

#### 2. Mapbox

- **免费额度**：50,000次地图加载/月
- **超出后**：$5.00 / 1,000次
- **优点**：界面美观，功能丰富
- **缺点**：超出免费额度后比Google Maps贵

#### 3. 百度地图 / 高德地图（中国用户）

- 适合主要面向中国用户的应用
- 有免费额度，但需要企业认证

### 1.5 重要提醒

1. **必须绑定结算账户**：即使只使用免费额度，也需要绑定信用卡
2. **监控使用量**：定期检查API使用情况，避免意外超支
3. **设置预算告警**：在Google Cloud Console设置预算和告警
4. **API密钥安全**：不要在前端代码中暴露未限制的API密钥
5. **测试环境**：开发时使用测试API密钥，避免消耗生产配额

### 1.6 成本优化建议

对于LinkU平台的具体优化：

1. **地理编码缓存**：
   - 相同城市/地址只编码一次
   - 将结果存储在数据库中

2. **按需加载**：
   - 任务列表默认不显示地图
   - 用户点击"地图视图"时才加载

3. **批量处理**：
   - 任务发布时，如果选择已有城市，直接使用预设坐标
   - 减少不必要的Geocoding请求

4. **使用城市预设坐标**：
   ```typescript
   // 使用预设坐标，避免每次地理编码
   const UK_CITIES_COORDINATES = {
     'London': { lat: 51.5074, lng: -0.1278 },
     // ... 其他城市
   };
   ```

### 1.7 预算设置示例

在Google Cloud Console设置预算：

1. 进入"预算和告警"
2. 创建预算：$50/月（作为安全阈值）
3. 设置告警：
   - 50%时通知（$25）
   - 90%时通知（$45）
   - 100%时通知（$50）

这样可以及时发现异常使用情况。

## 二、技术方案

### 2.1 技术选型

**前端库选择：**
- **@react-google-maps/api**: React官方推荐的Google Maps React封装库
- **@types/google.maps**: TypeScript类型定义

**API服务：**
- Google Maps JavaScript API
- Google Places API (用于地址自动完成)
- Google Geocoding API (用于地址与坐标转换)

### 2.2 架构设计

```
frontend/src/
├── components/
│   ├── GoogleMap/
│   │   ├── GoogleMapContainer.tsx      # 地图容器组件
│   │   ├── LocationPicker.tsx          # 位置选择器组件
│   │   ├── TaskMapView.tsx             # 任务地图视图组件
│   │   └── AddressAutocomplete.tsx     # 地址自动完成组件
│   └── ...
├── config/
│   └── googleMaps.ts                   # Google Maps配置
└── hooks/
    └── useGoogleMaps.ts                # Google Maps自定义Hook
```

## 三、实现步骤

### 3.1 安装依赖

```bash
cd frontend
npm install @react-google-maps/api
npm install --save-dev @types/google.maps
```

### 3.2 环境变量配置

在 `frontend/.env` 和 `frontend/.env.production` 中添加：

```env
REACT_APP_GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
```

**获取API密钥步骤：**
1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建新项目或选择现有项目
3. 启用以下API：
   - Maps JavaScript API
   - Places API
   - Geocoding API
4. 创建API密钥
5. 配置API密钥限制（推荐）：
   - 应用限制：HTTP引荐来源网址
   - API限制：仅限上述三个API

### 3.3 创建配置文件

**文件：`frontend/src/config/googleMaps.ts`**

```typescript
// Google Maps配置
export const GOOGLE_MAPS_CONFIG = {
  apiKey: process.env.REACT_APP_GOOGLE_MAPS_API_KEY || '',
  libraries: ['places', 'geometry'] as const,
  defaultCenter: {
    lat: 51.5074, // 伦敦默认坐标
    lng: -0.1278
  },
  defaultZoom: 10,
  mapOptions: {
    disableDefaultUI: false,
    zoomControl: true,
    streetViewControl: false,
    mapTypeControl: false,
    fullscreenControl: true,
  }
};

// 英国主要城市坐标（用于快速定位）
export const UK_CITIES_COORDINATES: Record<string, { lat: number; lng: number }> = {
  'London': { lat: 51.5074, lng: -0.1278 },
  'Edinburgh': { lat: 55.9533, lng: -3.1883 },
  'Manchester': { lat: 53.4808, lng: -2.2426 },
  'Birmingham': { lat: 52.4862, lng: -1.8904 },
  'Glasgow': { lat: 55.8642, lng: -4.2518 },
  'Bristol': { lat: 51.4545, lng: -2.5879 },
  'Sheffield': { lat: 53.3811, lng: -1.4701 },
  'Leeds': { lat: 53.8008, lng: -1.5491 },
  'Nottingham': { lat: 52.9548, lng: -1.1581 },
  'Newcastle': { lat: 54.9783, lng: -1.6178 },
  'Southampton': { lat: 50.9097, lng: -1.4044 },
  'Liverpool': { lat: 53.4084, lng: -2.9916 },
  'Cardiff': { lat: 51.4816, lng: -3.1791 },
  'Cambridge': { lat: 52.2053, lng: 0.1218 },
  'Oxford': { lat: 51.7520, lng: -1.2577 },
};
```

### 3.4 创建Google Maps容器组件

**文件：`frontend/src/components/GoogleMap/GoogleMapContainer.tsx`**

```typescript
import React from 'react';
import { GoogleMap, LoadScript, Marker } from '@react-google-maps/api';
import { GOOGLE_MAPS_CONFIG } from '../../config/googleMaps';

interface GoogleMapContainerProps {
  center?: { lat: number; lng: number };
  zoom?: number;
  markers?: Array<{ lat: number; lng: number; title?: string }>;
  onMapClick?: (e: google.maps.MapMouseEvent) => void;
  onMarkerClick?: (marker: { lat: number; lng: number }) => void;
  height?: string;
  width?: string;
  children?: React.ReactNode;
}

const GoogleMapContainer: React.FC<GoogleMapContainerProps> = ({
  center = GOOGLE_MAPS_CONFIG.defaultCenter,
  zoom = GOOGLE_MAPS_CONFIG.defaultZoom,
  markers = [],
  onMapClick,
  onMarkerClick,
  height = '400px',
  width = '100%',
  children
}) => {
  const mapContainerStyle = {
    width,
    height,
  };

  if (!GOOGLE_MAPS_CONFIG.apiKey) {
    return (
      <div style={{ 
        width, 
        height, 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'center',
        background: '#f0f0f0',
        border: '1px solid #ddd',
        borderRadius: '8px'
      }}>
        <p>Google Maps API密钥未配置</p>
      </div>
    );
  }

  return (
    <LoadScript
      googleMapsApiKey={GOOGLE_MAPS_CONFIG.apiKey}
      libraries={GOOGLE_MAPS_CONFIG.libraries}
    >
      <GoogleMap
        mapContainerStyle={mapContainerStyle}
        center={center}
        zoom={zoom}
        options={GOOGLE_MAPS_CONFIG.mapOptions}
        onClick={onMapClick}
      >
        {markers.map((marker, index) => (
          <Marker
            key={index}
            position={{ lat: marker.lat, lng: marker.lng }}
            title={marker.title}
            onClick={() => onMarkerClick?.(marker)}
          />
        ))}
        {children}
      </GoogleMap>
    </LoadScript>
  );
};

export default GoogleMapContainer;
```

### 3.5 创建位置选择器组件

**文件：`frontend/src/components/GoogleMap/LocationPicker.tsx`**

```typescript
import React, { useState, useCallback, useRef } from 'react';
import { GoogleMap, LoadScript, Marker } from '@react-google-maps/api';
import { Autocomplete } from '@react-google-maps/api';
import { GOOGLE_MAPS_CONFIG, UK_CITIES_COORDINATES } from '../../config/googleMaps';

interface LocationPickerProps {
  initialLocation?: { lat: number; lng: number; address?: string };
  onLocationChange: (location: { lat: number; lng: number; address: string }) => void;
  height?: string;
}

const LocationPicker: React.FC<LocationPickerProps> = ({
  initialLocation,
  onLocationChange,
  height = '400px'
}) => {
  const [selectedLocation, setSelectedLocation] = useState<{ lat: number; lng: number }>(
    initialLocation || GOOGLE_MAPS_CONFIG.defaultCenter
  );
  const [address, setAddress] = useState(initialLocation?.address || '');
  const [autocomplete, setAutocomplete] = useState<google.maps.places.Autocomplete | null>(null);
  const autocompleteRef = useRef<HTMLInputElement>(null);
  const geocoderRef = useRef<google.maps.Geocoder | null>(null);

  const onLoad = useCallback((autocomplete: google.maps.places.Autocomplete) => {
    setAutocomplete(autocomplete);
  }, []);

  const onPlaceChanged = useCallback(() => {
    if (autocomplete) {
      const place = autocomplete.getPlace();
      if (place.geometry?.location) {
        const lat = place.geometry.location.lat();
        const lng = place.geometry.location.lng();
        const newLocation = { lat, lng };
        setSelectedLocation(newLocation);
        setAddress(place.formatted_address || '');
        onLocationChange({ ...newLocation, address: place.formatted_address || '' });
      }
    }
  }, [autocomplete, onLocationChange]);

  const handleMapClick = useCallback((e: google.maps.MapMouseEvent) => {
    if (e.latLng) {
      const lat = e.latLng.lat();
      const lng = e.latLng.lng();
      const newLocation = { lat, lng };
      setSelectedLocation(newLocation);

      // 反向地理编码获取地址
      if (!geocoderRef.current) {
        geocoderRef.current = new google.maps.Geocoder();
      }
      geocoderRef.current.geocode(
        { location: { lat, lng } },
        (results, status) => {
          if (status === 'OK' && results && results[0]) {
            const formattedAddress = results[0].formatted_address;
            setAddress(formattedAddress);
            onLocationChange({ ...newLocation, address: formattedAddress });
          }
        }
      );
    }
  }, [onLocationChange]);

  const handleCitySelect = useCallback((cityName: string) => {
    const cityCoords = UK_CITIES_COORDINATES[cityName];
    if (cityCoords) {
      setSelectedLocation(cityCoords);
      setAddress(cityName);
      onLocationChange({ ...cityCoords, address: cityName });
    }
  }, [onLocationChange]);

  if (!GOOGLE_MAPS_CONFIG.apiKey) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <p>Google Maps API密钥未配置</p>
      </div>
    );
  }

  return (
    <LoadScript
      googleMapsApiKey={GOOGLE_MAPS_CONFIG.apiKey}
      libraries={GOOGLE_MAPS_CONFIG.libraries}
    >
      <div style={{ marginBottom: '16px' }}>
        <Autocomplete onLoad={onLoad} onPlaceChanged={onPlaceChanged}>
          <input
            ref={autocompleteRef}
            type="text"
            placeholder="搜索地址或选择城市..."
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            style={{
              width: '100%',
              padding: '12px',
              fontSize: '16px',
              border: '1px solid #ddd',
              borderRadius: '8px',
              marginBottom: '12px'
            }}
          />
        </Autocomplete>
        
        {/* 快速城市选择 */}
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', marginBottom: '12px' }}>
          {Object.keys(UK_CITIES_COORDINATES).slice(0, 8).map(city => (
            <button
              key={city}
              onClick={() => handleCitySelect(city)}
              style={{
                padding: '6px 12px',
                fontSize: '12px',
                border: '1px solid #ddd',
                borderRadius: '6px',
                background: '#fff',
                cursor: 'pointer'
              }}
            >
              {city}
            </button>
          ))}
        </div>
      </div>

      <GoogleMap
        mapContainerStyle={{ width: '100%', height }}
        center={selectedLocation}
        zoom={15}
        onClick={handleMapClick}
        options={GOOGLE_MAPS_CONFIG.mapOptions}
      >
        <Marker position={selectedLocation} draggable={true} />
      </GoogleMap>
      
      <div style={{ marginTop: '12px', fontSize: '14px', color: '#666' }}>
        <p>坐标: {selectedLocation.lat.toFixed(6)}, {selectedLocation.lng.toFixed(6)}</p>
        {address && <p>地址: {address}</p>}
      </div>
    </LoadScript>
  );
};

export default LocationPicker;
```

### 3.6 创建任务地图视图组件

**文件：`frontend/src/components/GoogleMap/TaskMapView.tsx`**

```typescript
import React, { useMemo } from 'react';
import GoogleMapContainer from './GoogleMapContainer';
import { UK_CITIES_COORDINATES } from '../../config/googleMaps';

interface Task {
  id: number;
  title: string;
  location: string;
  latitude?: number;
  longitude?: number;
}

interface TaskMapViewProps {
  tasks: Task[];
  selectedTaskId?: number;
  onTaskClick?: (taskId: number) => void;
  height?: string;
}

const TaskMapView: React.FC<TaskMapViewProps> = ({
  tasks,
  selectedTaskId,
  onTaskClick,
  height = '600px'
}) => {
  // 将任务转换为地图标记
  const markers = useMemo(() => {
    return tasks
      .filter(task => task.latitude && task.longitude)
      .map(task => ({
        lat: task.latitude!,
        lng: task.longitude!,
        title: task.title,
        taskId: task.id
      }));
  }, [tasks]);

  // 计算地图中心点（所有任务的平均位置）
  const mapCenter = useMemo(() => {
    if (markers.length === 0) {
      return { lat: 51.5074, lng: -0.1278 }; // 默认伦敦
    }
    
    const avgLat = markers.reduce((sum, m) => sum + m.lat, 0) / markers.length;
    const avgLng = markers.reduce((sum, m) => sum + m.lng, 0) / markers.length;
    return { lat: avgLat, lng: avgLng };
  }, [markers]);

  // 处理标记点击
  const handleMarkerClick = (marker: { lat: number; lng: number; taskId?: number }) => {
    if (marker.taskId && onTaskClick) {
      onTaskClick(marker.taskId);
    }
  };

  return (
    <GoogleMapContainer
      center={mapCenter}
      zoom={markers.length === 1 ? 15 : 10}
      markers={markers}
      onMarkerClick={handleMarkerClick}
      height={height}
    />
  );
};

export default TaskMapView;
```

### 3.7 创建自定义Hook

**文件：`frontend/src/hooks/useGoogleMaps.ts`**

```typescript
import { useState, useCallback, useRef } from 'react';

interface Location {
  lat: number;
  lng: number;
  address?: string;
}

export const useGoogleMaps = () => {
  const [location, setLocation] = useState<Location | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const geocoderRef = useRef<google.maps.Geocoder | null>(null);

  // 初始化Geocoder
  const initGeocoder = useCallback(() => {
    if (!geocoderRef.current && window.google) {
      geocoderRef.current = new window.google.maps.Geocoder();
    }
    return geocoderRef.current;
  }, []);

  // 地址转坐标
  const geocodeAddress = useCallback(async (address: string): Promise<Location | null> => {
    setLoading(true);
    setError(null);
    
    try {
      const geocoder = initGeocoder();
      if (!geocoder) {
        throw new Error('Geocoder未初始化');
      }

      return new Promise((resolve, reject) => {
        geocoder.geocode({ address }, (results, status) => {
          if (status === 'OK' && results && results[0]) {
            const location = {
              lat: results[0].geometry.location.lat(),
              lng: results[0].geometry.location.lng(),
              address: results[0].formatted_address
            };
            setLocation(location);
            resolve(location);
          } else {
            const errorMsg = `地理编码失败: ${status}`;
            setError(errorMsg);
            reject(new Error(errorMsg));
          }
          setLoading(false);
        });
      });
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : '未知错误';
      setError(errorMsg);
      setLoading(false);
      return null;
    }
  }, [initGeocoder]);

  // 坐标转地址
  const reverseGeocode = useCallback(async (lat: number, lng: number): Promise<string | null> => {
    setLoading(true);
    setError(null);
    
    try {
      const geocoder = initGeocoder();
      if (!geocoder) {
        throw new Error('Geocoder未初始化');
      }

      return new Promise((resolve, reject) => {
        geocoder.geocode({ location: { lat, lng } }, (results, status) => {
          if (status === 'OK' && results && results[0]) {
            const address = results[0].formatted_address;
            setLocation({ lat, lng, address });
            resolve(address);
          } else {
            const errorMsg = `反向地理编码失败: ${status}`;
            setError(errorMsg);
            reject(new Error(errorMsg));
          }
          setLoading(false);
        });
      });
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : '未知错误';
      setError(errorMsg);
      setLoading(false);
      return null;
    }
  }, [initGeocoder]);

  return {
    location,
    loading,
    error,
    geocodeAddress,
    reverseGeocode,
    setLocation
  };
};
```

## 四、数据库模型改动

### 4.1 任务表添加地理位置字段

```sql
-- 添加经纬度字段
ALTER TABLE tasks ADD COLUMN latitude DECIMAL(10, 8);
ALTER TABLE tasks ADD COLUMN longitude DECIMAL(11, 8);
ALTER TABLE tasks ADD COLUMN formatted_address TEXT;

-- 添加索引以支持地理位置查询
CREATE INDEX idx_tasks_location ON tasks(latitude, longitude);
CREATE INDEX idx_tasks_city_location ON tasks(location, latitude, longitude);
```

### 4.2 用户表添加位置信息

```sql
-- 如果用户表还没有这些字段
ALTER TABLE users ADD COLUMN latitude DECIMAL(10, 8);
ALTER TABLE users ADD COLUMN longitude DECIMAL(11, 8);
ALTER TABLE users ADD COLUMN formatted_address TEXT;
```

### 4.3 后端模型更新

**文件：`backend/app/models.py`**

在Task模型中添加：

```python
latitude = Column(Numeric(10, 8), nullable=True)
longitude = Column(Numeric(11, 8), nullable=True)
formatted_address = Column(Text, nullable=True)
```

## 五、后端API接口

### 5.1 任务创建/更新接口修改

**文件：`backend/app/routers.py`**

在任务创建和更新接口中添加地理位置处理：

```python
from geopy.geocoders import Nominatim
from geopy.exc import GeocoderTimedOut, GeocoderServiceError

async def geocode_location(location: str) -> dict:
    """地理编码：将地址转换为坐标"""
    try:
        geolocator = Nominatim(user_agent="linku_app")
        location_data = geolocator.geocode(location, timeout=10)
        if location_data:
            return {
                "latitude": float(location_data.latitude),
                "longitude": float(location_data.longitude),
                "formatted_address": location_data.address
            }
    except (GeocoderTimedOut, GeocoderServiceError) as e:
        logger.error(f"地理编码错误: {e}")
    return None

# 在任务创建接口中使用
@router.post("/tasks")
async def create_task(
    task_data: schemas.TaskCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # ... 现有代码 ...
    
    # 地理编码
    if task_data.location and task_data.location != "Online":
        geo_data = await geocode_location(task_data.location)
        if geo_data:
            task.latitude = geo_data["latitude"]
            task.longitude = geo_data["longitude"]
            task.formatted_address = geo_data["formatted_address"]
    
    # ... 保存任务 ...
```

### 5.2 添加地理位置搜索接口

```python
@router.get("/tasks/nearby")
async def get_nearby_tasks(
    latitude: float = Query(..., description="纬度"),
    longitude: float = Query(..., description="经度"),
    radius_km: float = Query(5.0, description="搜索半径（公里）"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """根据地理位置搜索附近的任务"""
    # 使用PostGIS或Haversine公式计算距离
    # 这里使用简化的Haversine公式
    from math import radians, cos, sin, asin, sqrt
    
    # 转换为弧度
    lat1, lon1 = radians(latitude), radians(longitude)
    
    # SQL查询（使用Haversine公式）
    query = """
    SELECT *, 
        (6371 * acos(
            cos(:lat1) * cos(radians(latitude)) * 
            cos(radians(longitude) - :lon1) + 
            sin(:lat1) * sin(radians(latitude))
        )) AS distance
    FROM tasks
    WHERE latitude IS NOT NULL 
        AND longitude IS NOT NULL
        AND status = 'open'
    HAVING distance < :radius
    ORDER BY distance
    LIMIT :limit OFFSET :offset
    """
    
    results = db.execute(
        text(query),
        {
            "lat1": lat1,
            "lon1": lon1,
            "radius": radius_km,
            "limit": limit,
            "offset": offset
        }
    ).fetchall()
    
    return results
```

## 六、前端页面集成

### 6.1 发布任务页面集成

**文件：`frontend/src/pages/PublishTask.tsx`**

在表单中添加地图选择器：

```typescript
import LocationPicker from '../components/GoogleMap/LocationPicker';

// 在组件状态中添加
const [mapLocation, setMapLocation] = useState<{
  lat: number;
  lng: number;
  address: string;
} | null>(null);

// 在表单中添加地图选择器
<div style={{ marginBottom: '24px' }}>
  <label>{t('publishTask.selectLocation')}</label>
  <LocationPicker
    onLocationChange={(location) => {
      setMapLocation(location);
      // 同时更新表单的location字段
      setForm({ ...form, location: location.address });
    }}
  />
</div>

// 提交时包含地理位置信息
const submitTask = async () => {
  const taskData = {
    ...form,
    latitude: mapLocation?.lat,
    longitude: mapLocation?.lng,
    formatted_address: mapLocation?.address
  };
  // ... 提交逻辑 ...
};
```

### 6.2 任务详情页面集成

**文件：`frontend/src/pages/TaskDetail.tsx`**

显示任务位置地图：

```typescript
import GoogleMapContainer from '../components/GoogleMap/GoogleMapContainer';

// 在任务详情中显示地图
{task.latitude && task.longitude && (
  <div style={{ marginTop: '24px' }}>
    <h3>{t('taskDetail.location')}</h3>
    <GoogleMapContainer
      center={{ lat: task.latitude, lng: task.longitude }}
      zoom={15}
      markers={[{
        lat: task.latitude,
        lng: task.longitude,
        title: task.title
      }]}
      height="300px"
    />
    {task.formatted_address && (
      <p style={{ marginTop: '8px', color: '#666' }}>
        {task.formatted_address}
      </p>
    )}
  </div>
)}
```

### 6.3 任务列表页面集成

**文件：`frontend/src/pages/Tasks.tsx`**

添加地图视图切换：

```typescript
import TaskMapView from '../components/GoogleMap/TaskMapView';

// 添加视图切换状态
const [viewMode, setViewMode] = useState<'list' | 'map'>('list');

// 添加视图切换按钮
<div style={{ marginBottom: '16px' }}>
  <button onClick={() => setViewMode('list')}>列表视图</button>
  <button onClick={() => setViewMode('map')}>地图视图</button>
</div>

// 根据视图模式渲染
{viewMode === 'map' ? (
  <TaskMapView
    tasks={filteredTasks}
    onTaskClick={(taskId) => {
      // 打开任务详情
      navigate(`/task/${taskId}`);
    }}
  />
) : (
  // 现有的列表视图
)}
```

## 七、国际化支持

### 7.1 添加翻译文本

**文件：`frontend/src/locales/en.json`**

```json
{
  "publishTask": {
    "selectLocation": "Select Location",
    "locationOnMap": "Location on Map",
    "searchAddress": "Search address or select city..."
  },
  "taskDetail": {
    "location": "Location",
    "viewOnMap": "View on Map"
  },
  "tasks": {
    "mapView": "Map View",
    "listView": "List View",
    "nearbyTasks": "Nearby Tasks"
  }
}
```

**文件：`frontend/src/locales/zh.json`**

```json
{
  "publishTask": {
    "selectLocation": "选择位置",
    "locationOnMap": "地图位置",
    "searchAddress": "搜索地址或选择城市..."
  },
  "taskDetail": {
    "location": "位置",
    "viewOnMap": "在地图上查看"
  },
  "tasks": {
    "mapView": "地图视图",
    "listView": "列表视图",
    "nearbyTasks": "附近任务"
  }
}
```

## 八、性能优化

### 8.1 地图加载优化

1. **延迟加载**：只在需要时加载地图组件
2. **标记聚合**：当标记过多时使用标记聚合（Marker Clustering）
3. **缓存地理编码结果**：避免重复的地理编码请求

### 8.2 使用标记聚合库

```bash
npm install @react-google-maps/marker-clusterer
```

```typescript
import { MarkerClusterer } from '@react-google-maps/marker-clusterer';

// 在GoogleMapContainer中使用
<MarkerClusterer>
  {(clusterer) =>
    markers.map((marker, index) => (
      <Marker
        key={index}
        position={{ lat: marker.lat, lng: marker.lng }}
        clusterer={clusterer}
      />
    ))
  }
</MarkerClusterer>
```

## 九、安全注意事项

1. **API密钥保护**：
   - 不要在前端代码中硬编码API密钥
   - 使用环境变量
   - 配置API密钥限制（HTTP引荐来源、IP限制等）

2. **请求限制**：
   - 实施速率限制，防止滥用
   - 监控API使用量

3. **数据验证**：
   - 验证用户输入的坐标范围
   - 防止坐标注入攻击

## 十、测试计划

### 10.1 功能测试

- [ ] 地图加载和显示
- [ ] 位置选择器功能
- [ ] 地址自动完成
- [ ] 坐标与地址转换
- [ ] 任务地图标记显示
- [ ] 地图视图切换
- [ ] 附近任务搜索

### 10.2 兼容性测试

- [ ] 不同浏览器测试（Chrome, Firefox, Safari, Edge）
- [ ] 移动端响应式测试
- [ ] API密钥缺失时的降级处理

### 10.3 性能测试

- [ ] 大量标记时的性能
- [ ] 地图加载速度
- [ ] 地理编码响应时间

## 十一、部署检查清单

- [ ] 在Google Cloud Console中创建API密钥
- [ ] 启用必要的Google Maps API
- [ ] 配置API密钥限制
- [ ] 在环境变量中添加API密钥
- [ ] 测试生产环境地图加载
- [ ] 验证API使用配额
- [ ] 设置API使用监控和告警

## 十二、后续优化方向

1. **高级功能**：
   - 路线规划
   - 距离计算
   - 地理围栏
   - 实时位置追踪

2. **用户体验**：
   - 保存常用位置
   - 位置历史记录
   - 离线地图支持

3. **数据分析**：
   - 任务位置热力图
   - 区域任务分布统计
   - 用户位置偏好分析

## 十三、参考资源

- [Google Maps JavaScript API文档](https://developers.google.com/maps/documentation/javascript)
- [@react-google-maps/api文档](https://react-google-maps-api-docs.netlify.app/)
- [Google Places API文档](https://developers.google.com/maps/documentation/places/web-service)
- [Google Geocoding API文档](https://developers.google.com/maps/documentation/geocoding)

---

**开发日期**: 2024年
**开发者**: LinkU开发团队
**状态**: 待实现

