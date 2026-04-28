# RAP2 API 参考

## 认证

### POST /account/login
登录接口

**请求参数：**
```json
{
  "email": "user@example.com",
  "password": "password"
}
```

**响应：**
```json
{
  "data": {
    "id": 1,
    "fullname": "用户名",
    "email": "user@example.com"
  }
}
```

### GET /account/info
获取当前登录用户信息

**响应：**
```json
{
  "data": {
    "id": 1,
    "fullname": "用户名",
    "email": "user@example.com"
  }
}
```

## 组织

### GET /organization/list
获取组织列表

**查询参数：**
- `name` - 组织名称搜索
- `cursor` - 分页游标
- `limit` - 每页数量

**响应：**
```json
{
  "data": [
    {
      "id": 1,
      "name": "组织名称",
      "description": "组织描述",
      "creator": { "id": 1, "fullname": "创建者" },
      "members": []
    }
  ],
  "pagination": {
    "total": 100,
    "cursor": 1,
    "limit": 10
  }
}
```

### GET /organization/get
获取组织详情

**查询参数：**
- `id` - 组织ID

## 仓库

### GET /repository/list
获取仓库列表

**查询参数：**
- `name` - 仓库名称搜索
- `organization` - 组织ID
- `user` - 用户ID
- `cursor` - 分页游标
- `limit` - 每页数量

**响应：**
```json
{
  "isOk": true,
  "data": [
    {
      "id": 1,
      "name": "仓库名称",
      "description": "仓库描述",
      "creator": {},
      "owner": {},
      "members": [],
      "collaborators": [],
      "canUserEdit": true
    }
  ],
  "pagination": {}
}
```

### GET /repository/get
获取仓库详情

**查询参数：**
- `id` - 仓库ID

## 模块

### GET /module/list
获取模块列表

**查询参数：**
- `repositoryId` - 仓库ID

**响应：**
```json
{
  "data": [
    {
      "id": 1,
      "name": "模块名称",
      "description": "模块描述",
      "repositoryId": 1,
      "interfaces": []
    }
  ]
}
```

### GET /module/get
获取模块详情

**查询参数：**
- `id` - 模块ID

## 接口

### GET /interface/list
获取接口列表

**查询参数：**
- `moduleId` - 模块ID

**响应：**
```json
{
  "data": [
    {
      "id": 1,
      "name": "接口名称",
      "url": "/api/user/info",
      "method": "GET",
      "description": "接口描述",
      "moduleId": 1,
      "requestProperties": [],
      "responseProperties": []
    }
  ]
}
```

### GET /interface/get
获取接口详情

**查询参数：**
- `id` - 接口ID

### POST /interface/create
创建接口

**请求参数：**
```json
{
  "moduleId": 1,
  "name": "接口名称",
  "url": "/api/path",
  "method": "GET",
  "description": "描述",
  "requestProperties": [],
  "responseProperties": []
}
```

### POST /interface/update
更新接口

**请求参数：**
```json
{
  "id": 1,
  "name": "新名称",
  "url": "/api/new-path",
  "method": "POST",
  "description": "新描述"
}
```

### POST /interface/delete
删除接口

**请求参数：**
```json
{
  "id": 1
}
```

## 属性

### GET /property/list
获取属性列表

**查询参数：**
- `interfaceId` - 接口ID
- `scope` - 范围（request/response）

**响应：**
```json
{
  "data": [
    {
      "id": 1,
      "name": "属性名",
      "type": "String",
      "description": "属性描述",
      "required": true,
      "interfaceId": 1,
      "scope": "request"
    }
  ]
}
```

## Mock 服务

### GET /mock/{repositoryId}/{url}
获取 Mock 数据

**示例：**
```
GET /mock/123/api/user/info
```

## 数据类型

### 属性类型
- `String` - 字符串
- `Number` - 数字
- `Boolean` - 布尔值
- `Object` - 对象
- `Array` - 数组
- `Function` - 函数
- `RegExp` - 正则表达式

### HTTP 方法
- `GET`
- `POST`
- `PUT`
- `DELETE`
- `PATCH`
- `HEAD`
- `OPTIONS`

## 错误码

| 错误码 | 说明 |
|--------|------|
| 401 | 未登录 |
| 403 | 无权限 |
| 404 | 资源不存在 |
| 500 | 服务器错误 |
