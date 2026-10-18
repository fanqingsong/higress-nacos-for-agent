package com.example.mcp.tools;

import com.example.mcp.entity.Order;
import com.example.mcp.service.OrderService;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;

@Service
public class OrderMcpTools {

    private final OrderService orderService;

    public OrderMcpTools(OrderService orderService) {
        this.orderService = orderService;
    }

    @Tool(description = "获取所有订单", name = "getAllOrders")
    public List<Order> getAllOrders() {
        return orderService.getAllOrders();
    }

    @Tool(description = "创建订单", name = "createOrder")
    public Order createOrder(
            @ToolParam(description = "用户 ID") String userId,
            @ToolParam(description = "产品名称") String product,
            @ToolParam(description = "数量") Integer quantity,
            @ToolParam(description = "单价") Double price,
            @ToolParam(description = "订单状态，默认 pending") String status) {
        Order order = new Order();
        order.setUserId(userId);
        order.setProduct(product);
        order.setQuantity(quantity);
        if (price != null) {
            order.setPrice(BigDecimal.valueOf(price));
        }
        order.setStatus(status != null ? status : "pending");
        return orderService.createOrder(order);
    }

    @Tool(description = "根据 ID 获取订单", name = "getOrderById")
    public Order getOrderById(@ToolParam(description = "订单 ID") String id) {
        Order order = orderService.getOrderById(id);
        if (order == null) {
            throw new NoSuchElementException("订单不存在: " + id);
        }
        return order;
    }

    @Tool(description = "更新订单状态", name = "updateOrderStatus")
    public Map<String, Object> updateOrderStatus(
            @ToolParam(description = "订单 ID") String id,
            @ToolParam(description = "新状态") String status) {
        boolean updated = orderService.updateOrderStatus(id, status);
        return Map.of("id", id, "status", status, "updated", updated);
    }

    @Tool(description = "根据用户 ID 获取订单", name = "getOrdersByUserId")
    public List<Order> getOrdersByUserId(@ToolParam(description = "用户 ID") String userId) {
        return orderService.getOrdersByUserId(userId);
    }
}
