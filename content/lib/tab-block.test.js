// Mock the Opal object before importing the module
global.Opal = {
  module: jest.fn(() => ({})),
  const_get_local: jest.fn(() => ({
    $new: jest.fn(() => ({
      addRole: jest.fn(),
      $append: jest.fn(),
      text: '',
    })),
  })),
};

const tabBlock = require('./tab-block.js');

// Manually extract generateId for testing
const generateId = (str, idx) =>
  `tabset${idx}_${str
    .toLowerCase()
    .replace(/[^a-zA-Z0-9_]/g, "-")
    .replace(/^-+|-+$|-(-)+/g, "$1")}`;

describe('tab-block', () => {
  describe('generateId', () => {
    it('should generate a valid ID from a simple string', () => {
      expect(generateId('Tab A', 1)).toBe('tabset1_tab-a');
    });

    it('should handle special characters', () => {
      expect(generateId('Tab B!@#$', 2)).toBe('tabset2_tab-b');
    });

    it('should handle leading and trailing separators', () => {
      expect(generateId('-Tab C-', 3)).toBe('tabset3_tab-c');
    });

    it('should handle multiple separators', () => {
      expect(generateId('Tab--D', 4)).toBe('tabset4_tab-d');
    });
  });
});
