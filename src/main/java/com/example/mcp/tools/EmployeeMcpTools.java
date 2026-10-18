package com.example.mcp.tools;

import com.example.mcp.entity.Employee;
import com.example.mcp.service.EmployeeService;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class EmployeeMcpTools {

    private final EmployeeService employeeService;

    public EmployeeMcpTools(EmployeeService employeeService) {
        this.employeeService = employeeService;
    }

    @Tool(description = "根据姓名查询员工岗位", name = "getJobPosition")
    public Map<String, Object> getJobPosition(@ToolParam(description = "员工姓名") String name) {
        Employee employee = employeeService.getEmployeeByName(name);
        if (employee != null) {
            return Map.of("name", employee.getName(), "position", employee.getPosition());
        }
        return Map.of("name", name, "position", "未找到该人员信息");
    }

    @Tool(description = "更新员工岗位", name = "updateEmployeePosition")
    public Map<String, Object> updateEmployeePosition(
            @ToolParam(description = "员工姓名") String name,
            @ToolParam(description = "新岗位") String position) {
        boolean updated = employeeService.updateEmployeePosition(name, position);
        return Map.of("name", name, "position", position, "updated", updated);
    }

    @Tool(description = "获取所有员工", name = "getAllEmployees")
    public List<Employee> getAllEmployees() {
        return employeeService.getAllEmployees();
    }

    @Tool(description = "创建员工", name = "createEmployee")
    public Employee createEmployee(
            @ToolParam(description = "员工姓名") String name,
            @ToolParam(description = "工作岗位") String position) {
        Employee newEmployee = new Employee();
        newEmployee.setName(name);
        newEmployee.setPosition(position);
        return employeeService.createEmployee(newEmployee);
    }

    @Tool(description = "删除员工", name = "deleteEmployee")
    public Map<String, Object> deleteEmployee(@ToolParam(description = "员工 ID") Integer id) {
        boolean deleted = employeeService.deleteEmployee(id);
        return Map.of("id", id, "deleted", deleted);
    }
}
