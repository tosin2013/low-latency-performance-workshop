const register = require('./remote-include-processor.js');

describe('remote-include-processor', () => {
  it('should register without errors', () => {
    const self = {
      includeProcessor: jest.fn(function (callback) {
        const processor = {
          $option: jest.fn(),
          handles: jest.fn(),
          process: jest.fn(),
        };
        callback.call(processor);
      }),
    };
    expect(() => register.call(self)).not.toThrow();
  });
});
