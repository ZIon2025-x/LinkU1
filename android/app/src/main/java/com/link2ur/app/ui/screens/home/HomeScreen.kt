package com.linku.app.ui.screens.home

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.linku.app.viewmodel.HomeViewModel

@Composable
fun HomeScreen() {
    val viewModel: HomeViewModel = androidx.lifecycle.viewmodel.compose.viewModel()
    val featuredTasks by viewModel.featuredTasks.collectAsState()
    val recentTasks by viewModel.recentTasks.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    
    LaunchedEffect(Unit) {
        viewModel.loadData()
    }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        // 欢迎区域
        Text(
            text = "欢迎使用 Link2Ur",
            style = MaterialTheme.typography.headlineLarge
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = "连接、能力、创造",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        // 快速操作
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // 注意：需要从导航中获取navController
            // 这里暂时保留占位，实际使用时需要传入navController
            Button(
                onClick = { /* TODO: 导航到发布任务 */ },
                modifier = Modifier.weight(1f)
            ) {
                Text("发布任务")
            }
            
            Button(
                onClick = { /* TODO: 导航到发布商品 */ },
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.secondary
                )
            ) {
                Text("发布商品")
            }
        }
        
        Spacer(modifier = Modifier.height(32.dp))
        
        // 推荐任务
        if (featuredTasks.isNotEmpty()) {
            Text(
                text = "推荐任务",
                style = MaterialTheme.typography.titleLarge
            )
            
            Spacer(modifier = Modifier.height(12.dp))
            
            LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                items(featuredTasks.take(5)) { task ->
                    FeaturedTaskCard(task = task)
                }
            }
        }
        
        Spacer(modifier = Modifier.height(32.dp))
        
        // 最新任务
        if (recentTasks.isNotEmpty()) {
            Text(
                text = "最新任务",
                style = MaterialTheme.typography.titleLarge
            )
            
            Spacer(modifier = Modifier.height(12.dp))
            
            recentTasks.take(3).forEach { task ->
                TaskCard(task = task)
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
        
        if (isLoading && featuredTasks.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = androidx.compose.ui.Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        }
    }
}

@Composable
fun FeaturedTaskCard(task: com.linku.app.data.models.Task) {
    Card(
        modifier = Modifier.width(200.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(
                text = task.title,
                style = MaterialTheme.typography.titleMedium,
                maxLines = 2
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "£${task.reward}",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
fun TaskCard(task: com.linku.app.data.models.Task) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = task.title,
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = task.description,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 2
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = task.location,
                    style = MaterialTheme.typography.bodySmall
                )
                Text(
                    text = "£${task.reward}",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}

