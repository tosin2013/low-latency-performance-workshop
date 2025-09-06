const { register } = require('./dev-mode.js');

// Mock functions and objects that are not relevant to the test
const getUniqueOrigins = jest.fn();
const getNavEntriesByUrl = jest.fn();

describe('dev-mode', () => {
  let contentCatalog;
  let playbook;
  let componentVersion;
  let component;

  beforeEach(() => {
    // Reset mocks before each test
    getUniqueOrigins.mockClear();
    getNavEntriesByUrl.mockClear();

    // Mock the contentCatalog
    contentCatalog = {
      getComponents: jest.fn(() => [component]),
      addFile: jest.fn(),
      findBy: jest.fn(() => []),
    };

    // Mock the playbook
    playbook = {
      asciidoc: {
        attributes: {
          'site-attribute': 'site-value',
        },
      },
    };

    // Mock a component version
    componentVersion = {
      version: '1.0',
      name: 'test-component',
      descriptor: {
        asciidoc: {
          attributes: {
            'component-attribute': 'component-value',
          },
        },
      },
    };

    // Mock a component
    component = {
      versions: [componentVersion],
    };
  });

  it('should register without errors', () => {
    const registry = {
      once: jest.fn(),
      on: jest.fn(),
    };
    expect(() => register.call(registry, { config: {} })).not.toThrow();
  });
});
