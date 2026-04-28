#!/usr/bin/env node

/**
 * 根据 RAP2 接口生成前端调用代码
 * 
 * 用法: node generate-code.js <rap2-api-url> <interface-id> [type]
 * type: axios | miniprogram | flutter (默认: axios)
 */

const https = require('https');
const http = require('http');

/**
 * 获取接口详情
 */
function fetchInterface(baseUrl, interfaceId) {
  return new Promise((resolve, reject) => {
    const url = new URL(`/interface/get?id=${interfaceId}`, baseUrl);
    const client = url.protocol === 'https:' ? https : http;
    
    const req = client.get(url.toString(), (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          resolve(json.data);
        } catch (e) {
          reject(e);
        }
      });
    });
    
    req.on('error', reject);
  });
}

/**
 * 生成 axios 代码
 */
function generateAxiosCode(iface) {
  const method = iface.method.toLowerCase();
  const hasParams = iface.requestProperties && iface.requestProperties.length > 0;
  
  // 生成参数定义
  const paramsDef = hasParams 
    ? iface.requestProperties.map(p => `${p.name}: ${mapTsType(p.type)}`).join(', ')
    : '';
  
  // 生成请求数据
  const dataCode = hasParams
    ? `{ ${iface.requestProperties.map(p => p.name).join(', ')} }`
    : '{}';
  
  return `
/**
 * ${iface.name}
 * ${iface.description || ''}
 * @url ${iface.url}
 * @method ${iface.method}
 */
export function ${toCamelCase(iface.name)}(${paramsDef}) {
  return request.${method}('${iface.url}', {
    ${method === 'get' ? 'params' : 'data'}: ${dataCode}
  });
}

// 响应类型定义
export interface ${toPascalCase(iface.name)}Response {
${iface.responseProperties?.map(p => `  ${p.name}: ${mapTsType(p.type)}; // ${p.description || ''}`).join('\n') || '  // 无响应数据'}
}
`;
}

/**
 * 生成小程序代码
 */
function generateMiniProgramCode(iface) {
  const method = iface.method.toUpperCase();
  const hasParams = iface.requestProperties && iface.requestProperties.length > 0;
  
  return `
/**
 * ${iface.name}
 * ${iface.description || ''}
 * @url ${iface.url}
 * @method ${iface.method}
 */
export function ${toCamelCase(iface.name)}(${hasParams ? 'data = {}' : ''}) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: getBaseUrl() + '${iface.url}',
      method: '${method}',
      header: {
        'Content-Type': 'application/json'
      },
      ${method === 'GET' ? 'data: data' : 'data: JSON.stringify(data)'},
      success: (res) => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(res.data);
        } else {
          reject(new Error(res.data?.message || 'Request failed'));
        }
      },
      fail: reject
    });
  });
}
`;
}

/**
 * 生成 Flutter 代码
 */
function generateFlutterCode(iface) {
  const className = toPascalCase(iface.name);
  const hasParams = iface.requestProperties && iface.requestProperties.length > 0;
  
  // 生成请求参数类
  const requestClass = hasParams ? `
/// ${iface.name} 请求参数
class ${className}Request {
${iface.requestProperties.map(p => `  final ${mapDartType(p.type)} ${p.name};`).join('\n')}

  ${className}Request({
${iface.requestProperties.map(p => `    required this.${p.name},`).join('\n')}
  });

  Map<String, dynamic> toJson() => {
${iface.requestProperties.map(p => `    '${p.name}': ${p.name},`).join('\n')}
  };
}` : '';

  // 生成响应数据类
  const responseClass = iface.responseProperties?.length > 0 ? `
/// ${iface.name} 响应数据
class ${className}Response {
${iface.responseProperties.map(p => `  final ${mapDartType(p.type)} ${p.name};`).join('\n')}

  ${className}Response({
${iface.responseProperties.map(p => `    required this.${p.name},`).join('\n')}
  });

  factory ${className}Response.fromJson(Map<String, dynamic> json) {
    return ${className}Response(
${iface.responseProperties.map(p => `      ${p.name}: json['${p.name}'],`).join('\n')}
    );
  }
}` : '';

  return `${requestClass}
${responseClass}

/// ${iface.name}
/// ${iface.description || ''}
class ${className}Api {
  final Dio _dio;

  ${className}Api(this._dio);

  Future<${iface.responseProperties?.length > 0 ? `${className}Response` : 'dynamic'}> call(${hasParams ? `${className}Request request` : ''}) async {
    try {
      final response = await _dio.${iface.method.toLowerCase()}(
        '${iface.url}',
        ${hasParams ? 'data: request.toJson(),' : ''}
      );
      return ${iface.responseProperties?.length > 0 ? `${className}Response.fromJson(response.data)` : 'response.data'};
    } catch (e) {
      throw Exception('Request failed: \$e');
    }
  }
}
`;
}

/**
 * 类型映射到 TypeScript
 */
function mapTsType(rap2Type) {
  const map = {
    'String': 'string',
    'Number': 'number',
    'Boolean': 'boolean',
    'Object': 'Record<string, any>',
    'Array': 'any[]',
    'Function': 'Function',
    'RegExp': 'RegExp'
  };
  return map[rap2Type] || 'any';
}

/**
 * 类型映射到 Dart
 */
function mapDartType(rap2Type) {
  const map = {
    'String': 'String',
    'Number': 'double',
    'Boolean': 'bool',
    'Object': 'Map<String, dynamic>',
    'Array': 'List<dynamic>',
    'Function': 'Function',
    'RegExp': 'RegExp'
  };
  return map[rap2Type] || 'dynamic';
}

/**
 * 转换为 camelCase
 */
function toCamelCase(str) {
  return str.replace(/[-_](\w)/g, (_, c) => c.toUpperCase());
}

/**
 * 转换为 PascalCase
 */
function toPascalCase(str) {
  const camel = toCamelCase(str);
  return camel.charAt(0).toUpperCase() + camel.slice(1);
}

/**
 * 主函数
 */
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length < 2) {
    console.log('用法: node generate-code.js <rap2-api-url> <interface-id> [type]');
    console.log('');
    console.log('参数:');
    console.log('  rap2-api-url  RAP2 API 地址，如 http://localhost:38080');
    console.log('  interface-id  接口 ID');
    console.log('  type          代码类型: axios | miniprogram | flutter (默认: axios)');
    console.log('');
    console.log('示例:');
    console.log('  node generate-code.js http://localhost:38080 123 axios');
    console.log('  node generate-code.js http://localhost:38080 123 miniprogram');
    process.exit(1);
  }
  
  const [baseUrl, interfaceId, type = 'axios'] = args;
  
  try {
    console.log(`正在获取接口 ${interfaceId}...`);
    const iface = await fetchInterface(baseUrl, interfaceId);
    
    if (!iface) {
      console.error('接口不存在');
      process.exit(1);
    }
    
    console.log(`接口: ${iface.name}`);
    console.log(`URL: ${iface.url}`);
    console.log(`Method: ${iface.method}`);
    console.log('');
    
    let code;
    switch (type) {
      case 'axios':
        code = generateAxiosCode(iface);
        break;
      case 'miniprogram':
        code = generateMiniProgramCode(iface);
        break;
      case 'flutter':
        code = generateFlutterCode(iface);
        break;
      default:
        console.error(`不支持的类型: ${type}`);
        process.exit(1);
    }
    
    console.log('生成的代码:');
    console.log('---');
    console.log(code);
    
  } catch (error) {
    console.error('错误:', error.message);
    process.exit(1);
  }
}

main();
