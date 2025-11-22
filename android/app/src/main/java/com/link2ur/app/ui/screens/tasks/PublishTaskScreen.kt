package com.linku.app.ui.screens.tasks

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.linku.app.viewmodel.PublishTaskViewModel

@Composable
fun PublishTaskScreen(
    navController: NavController,
    viewModel: PublishTaskViewModel = androidx.lifecycle.viewmodel.compose.viewModel()
) {
    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var taskType by remember { mutableStateOf("") }
    var location by remember { mutableStateOf("") }
    var reward by remember { mutableStateOf("") }
    var deadline by remember { mutableStateOf("") }
    var isFlexible by remember { mutableStateOf(false) }
    
    val isLoading by viewModel.isLoading.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val publishSuccess by viewModel.publishSuccess.collectAsState()
    
    LaunchedEffect(publishSuccess) {
        if (publishSuccess) {
            navController.popBackStack()
        }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("发布任务") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "返回")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("任务标题 *") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )
            
            OutlinedTextField(
                value = description,
                onValueChange = { description = it },
                label = { Text("任务描述 *") },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp),
                maxLines = 5
            )
            
            OutlinedTextField(
                value = taskType,
                onValueChange = { taskType = it },
                label = { Text("任务类型 *") },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("如：配送、清洁、维修等") }
            )
            
            OutlinedTextField(
                value = location,
                onValueChange = { location = it },
                label = { Text("地点 *") },
                modifier = Modifier.fillMaxWidth()
            )
            
            OutlinedTextField(
                value = reward,
                onValueChange = { reward = it },
                label = { Text("报酬 (£) *") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )
            
            OutlinedTextField(
                value = deadline,
                onValueChange = { deadline = it },
                label = { Text("截止日期") },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("YYYY-MM-DD") }
            )
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
            ) {
                Checkbox(
                    checked = isFlexible,
                    onCheckedChange = { isFlexible = it }
                )
                Text("时间灵活")
            }
            
            if (errorMessage != null) {
                Text(
                    text = errorMessage!!,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall
                )
            }
            
            Button(
                onClick = {
                    val rewardValue = reward.toDoubleOrNull() ?: 0.0
                    viewModel.publishTask(
                        title = title,
                        description = description,
                        taskType = taskType,
                        location = location,
                        reward = rewardValue,
                        deadline = deadline.ifEmpty { null },
                        isFlexible = if (isFlexible) 1 else 0
                    )
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isLoading && title.isNotBlank() && description.isNotBlank() 
                        && taskType.isNotBlank() && location.isNotBlank() && reward.isNotBlank()
            ) {
                if (isLoading) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp))
                } else {
                    Text("发布任务")
                }
            }
        }
    }
}

