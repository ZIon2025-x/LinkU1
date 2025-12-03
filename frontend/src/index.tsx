import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import reportWebVitals from './reportWebVitals';
import { autoFixHttp2 } from './utils/http2Fix';
import { setupNetworkMonitoring } from './utils/networkDiagnostics';
import { initWebVitalsMonitoring } from './utils/webVitalsReporter';

