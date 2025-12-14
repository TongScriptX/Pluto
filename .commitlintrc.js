module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',     // 新功能
        'fix',      // 修补缺陷
        'docs',     // 仅文档变动
        'style',    // 代码格式、无逻辑变更
        'refactor', // 重构
        'test',     // 补充缺失测试
        'chore',    // 杂项（升级依赖、脚本）
        'perf',     // 性能优化
        'ci',       // CI配置文件和脚本的变动
        'build',    // 构建系统或外部依赖的变动
        'revert',   // 回滚之前的提交
        'hotfix',   // 生产紧急修复
        'release'   // 版本发布
      ]
    ],
    'subject-case': [2, 'never', ['start-case', 'pascal-case', 'upper-case']],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],
    'header-max-length': [2, 'always', 72],
    'body-leading-blank': [1, 'always'],
    'body-max-line-length': [2, 'always', 72],
    'footer-leading-blank': [1, 'always'],
    'footer-max-line-length': [2, 'always', 72]
  }
};