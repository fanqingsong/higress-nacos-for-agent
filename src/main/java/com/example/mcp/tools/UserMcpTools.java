package com.example.mcp.tools;

import com.example.mcp.entity.User;
import com.example.mcp.service.UserService;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class UserMcpTools {

    private final UserService userService;

    public UserMcpTools(UserService userService) {
        this.userService = userService;
    }

    @Tool(description = "获取所有用户", name = "getAllUsers")
    public List<User> getAllUsers() {
        return userService.getAllUsers();
    }

    @Tool(description = "创建用户", name = "createUser")
    public User createUser(
            @ToolParam(description = "用户姓名") String name,
            @ToolParam(description = "用户邮箱") String email) {
        User newUser = new User();
        newUser.setName(name);
        newUser.setEmail(email);
        return userService.createUser(newUser);
    }

    @Tool(description = "根据 ID 获取用户", name = "getUserById")
    public User getUserById(@ToolParam(description = "用户 ID") String id) {
        return userService.getUserById(id);
    }

    @Tool(description = "更新用户", name = "updateUser")
    public User updateUser(
            @ToolParam(description = "用户 ID") String id,
            @ToolParam(description = "用户姓名") String name,
            @ToolParam(description = "用户邮箱") String email) {
        User updateUser = new User();
        updateUser.setName(name);
        updateUser.setEmail(email);
        return userService.updateUser(id, updateUser);
    }

    @Tool(description = "删除用户", name = "deleteUser")
    public Map<String, Object> deleteUser(@ToolParam(description = "用户 ID") String id) {
        boolean deleted = userService.deleteUser(id);
        return Map.of("id", id, "deleted", deleted);
    }

    @Tool(description = "根据名称搜索用户", name = "getUserByName")
    public List<User> getUserByName(@ToolParam(description = "用户姓名") String name) {
        return userService.getUserByName(name);
    }
}
