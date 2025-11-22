package com.linku.app.ui.screens.fleamarket

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Image
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.linku.app.data.models.FleaMarketItem
import com.linku.app.viewmodel.FleaMarketViewModel

@Composable
fun FleaMarketScreen() {
    val viewModel: FleaMarketViewModel = androidx.lifecycle.viewmodel.compose.viewModel()
    val items by viewModel.items.collectAsState()
    val categories by viewModel.categories.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    
    LaunchedEffect(Unit) {
        viewModel.loadCategories()
        viewModel.loadItems()
    }
    
    Column(modifier = Modifier.fillMaxSize()) {
        // 分类筛选
        LazyRow(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            item {
                FilterChip(
                    selected = true,
                    onClick = { },
                    label = { Text("全部") }
                )
            }
            items(categories) { category ->
                FilterChip(
                    selected = false,
                    onClick = { viewModel.loadItems(category = category) },
                    label = { Text(category) }
                )
            }
        }
        
        // 商品列表
        if (isLoading && items.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = androidx.compose.ui.Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(items) { item ->
                    FleaMarketItemCard(item = item)
                }
            }
        }
    }
}

@Composable
fun FleaMarketItemCard(item: FleaMarketItem) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        onClick = { /* 导航到商品详情 */ }
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            // 图片占位
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(150.dp)
                    .background(MaterialTheme.colorScheme.surfaceVariant),
                contentAlignment = androidx.compose.ui.Alignment.Center
            ) {
                if (item.images.isNotEmpty()) {
                    Text("图片")
                } else {
                    Icon(
                        imageVector = androidx.compose.material.icons.Icons.Default.Image,
                        contentDescription = null
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text(
                text = item.title,
                style = MaterialTheme.typography.titleSmall,
                maxLines = 2
            )
            
            Spacer(modifier = Modifier.height(4.dp))
            
            Text(
                text = "£${item.price}",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary
            )
            
            Spacer(modifier = Modifier.height(4.dp))
            
            Text(
                text = item.city,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

