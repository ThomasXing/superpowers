#!/usr/bin/env node

/**
 * Java Bean 转 RAP2 JSON 工具
 * 
 * 用法: node java-to-rap2.js <input.java> [output.json]
 */

const fs = require('fs');
const path = require('path');

// Java 类型到 RAP2 类型的映射
const typeMap = {
  'String': 'String',
  'Integer': 'Number',
  'int': 'Number',
  'Long': 'Number',
  'long': 'Number',
  'Double': 'Number',
  'double': 'Number',
  'Float': 'Number',
  'float': 'Number',
  'BigDecimal': 'Number',
  'Boolean': 'Boolean',
  'boolean': 'Boolean',
  'Date': 'String',
  'LocalDate': 'String',
  'LocalDateTime': 'String',
  'List': 'Array',
  'ArrayList': 'Array',
  'Set': 'Array',
  'HashSet': 'Array',
  'Map': 'Object',
  'HashMap': 'Object',
  'Object': 'Object'
};

/**
 * 解析 Java 类型为 RAP2 类型
 */
function parseJavaType(javaType) {
  // 去除空格
  javaType = javaType.trim();
  
  // 处理泛型
  if (javaType.includes('<')) {
    const baseType = javaType.split('<')[0];
    const genericType = javaType.match(/<(.+)>/)?.[1];
    
    return {
      type: typeMap[baseType] || 'Array',
      elementType: genericType ? parseJavaType(genericType) : { type: 'Object' }
    };
  }
  
  // 处理数组类型
  if (javaType.endsWith('[]')) {
    return {
      type: 'Array',
      elementType: parseJavaType(javaType.slice(0, -2))
    };
  }
  
  return {
    type: typeMap[javaType] || 'Object'
  };
}

/**
 * 从 Java 代码中提取类名
 */
function extractClassName(javaCode) {
  const classMatch = javaCode.match(/class\s+(\w+)/);
  return classMatch ? classMatch[1] : 'Unknown';
}

/**
 * 从 Java 代码中提取包名
 */
function extractPackageName(javaCode) {
  const packageMatch = javaCode.match(/package\s+([\w.]+);/);
  return packageMatch ? packageMatch[1] : '';
}

/**
 * 从 Java 代码中提取字段
 */
function extractFields(javaCode) {
  const fields = [];
  
  // 匹配字段定义: private Type name;
  // 支持泛型、注解、注释
  const fieldPattern = /(?:\/\*\*[\s\S]*?\*\/\s*)?(?:@\w+(?:\([^)]*\))?\s*)*(?:private|public|protected)\s+(\w+(?:<[^>]+>)?(?:\[\])?)\s+(\w+)\s*;/g;
  
  let match;
  while ((match = fieldPattern.exec(javaCode)) !== null) {
    const [, type, name] = match;
    
    // 提取字段注释
    const beforeMatch = javaCode.substring(0, match.index);
    const commentMatch = beforeMatch.match(/\/\*\*\s*([\s\S]*?)\s*\*\/(?:\s*@\w+)?\s*$/);
    let description = '';
    if (commentMatch) {
      description = commentMatch[1]
        .replace(/^\s*\*\s?/gm, '')
        .replace(/\s+/g, ' ')
        .trim();
    }
    
    const parsedType = parseJavaType(type);
    
    fields.push({
      name,
      type: parsedType.type,
      description,
      required: false
    });
  }
  
  return fields;
}

/**
 * 转换单个 Java 文件
 */
function convertJavaFile(inputPath) {
  const javaCode = fs.readFileSync(inputPath, 'utf-8');
  
  const className = extractClassName(javaCode);
  const packageName = extractPackageName(javaCode);
  const fields = extractFields(javaCode);
  
  return {
    name: className,
    description: packageName,
    properties: fields
  };
}

/**
 * 主函数
 */
function main() {
  const args = process.argv.slice(2);
  
  if (args.length < 1) {
    console.log('用法: node java-to-rap2.js <input.java|input-dir> [output.json]');
    console.log('');
    console.log('示例:');
    console.log('  node java-to-rap2.js UserDTO.java');
    console.log('  node java-to-rap2.js UserDTO.java output.json');
    console.log('  node java-to-rap2.js ./dto/ ./output.json');
    process.exit(1);
  }
  
  const inputPath = args[0];
  const outputPath = args[1] || 'rap2-output.json';
  
  let result;
  
  if (fs.statSync(inputPath).isDirectory()) {
    // 处理目录
    const files = fs.readdirSync(inputPath)
      .filter(f => f.endsWith('.java'))
      .map(f => path.join(inputPath, f));
    
    const modules = files.map(convertJavaFile);
    
    result = {
      name: path.basename(inputPath),
      description: 'Generated from Java beans',
      modules: modules.map(m => ({
        name: m.name,
        description: m.description,
        interfaces: [{
          name: m.name,
          url: '',
          method: 'GET',
          description: m.description,
          requestProperties: [],
          responseProperties: m.properties
        }]
      }))
    };
  } else {
    // 处理单个文件
    result = convertJavaFile(inputPath);
  }
  
  // 写入输出文件
  fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
  
  console.log(`✓ 转换完成: ${outputPath}`);
  console.log(`  类名: ${result.name || result.modules?.length + ' modules'}`);
  console.log(`  字段数: ${result.properties?.length || 'N/A'}`);
}

main();
