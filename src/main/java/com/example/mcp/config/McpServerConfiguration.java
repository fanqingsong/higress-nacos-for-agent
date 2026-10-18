package com.example.mcp.config;

import com.example.mcp.tools.EmployeeMcpTools;
import com.example.mcp.tools.OrderMcpTools;
import com.example.mcp.tools.UserMcpTools;
import org.springframework.ai.tool.ToolCallbackProvider;
import org.springframework.ai.tool.method.MethodToolCallbackProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class McpServerConfiguration {

    @Bean
    public ToolCallbackProvider demoMcpTools(
            UserMcpTools userMcpTools,
            OrderMcpTools orderMcpTools,
            EmployeeMcpTools employeeMcpTools) {
        return MethodToolCallbackProvider.builder()
                .toolObjects(userMcpTools, orderMcpTools, employeeMcpTools)
                .build();
    }
}
