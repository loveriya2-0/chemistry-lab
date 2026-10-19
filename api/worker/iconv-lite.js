// Stand-in for iconv-lite, which crashes when bundled for Workers (its
// "browser" field stubs out ./lib/streams). Express only uses it to decode
// request bodies, which TextDecoder covers.
const decoder = (encoding) => new TextDecoder(encoding);

module.exports = {
  encodingExists(encoding) {
    try {
      decoder(encoding);
      return true;
    } catch {
      return false;
    }
  },
  getDecoder(encoding) {
    const d = decoder(encoding);
    return { write: (buf) => d.decode(buf, { stream: true }), end: () => d.decode() };
  },
  decode: (buf, encoding) => decoder(encoding).decode(buf),
};
