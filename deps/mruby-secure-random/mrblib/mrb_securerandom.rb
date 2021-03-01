class SecureRandom
  class << self
    def random_bytes(n = nil)
      n = n ? n.to_i : 16
      b = File.open("/dev/urandom", "r") { |fh| fh.read(n) }
      if b.size != n
        raise "Unexpected partial read from random device: only #{ b.size } for #{ n } bytes"
      end
      b
    rescue
      raise File::NoFileError, "No random device"
    end

    def hex(n=nil)
      random_bytes(n).unpack("H*")[0]
    end

    def base64(n=nil)
      [random_bytes(n)].pack("m*").gsub("\n", "")
    end

    def urlsafe_base64(n=nil, padding=false)
      s = base64.gsub("+", "-").gsub("/", "_")
      s.gsub!("=", "") unless padding
      s
    end

    def random_number(n=0)
      if 0 < n
        hex = n.to_s(16)
        hex = '0' + hex if (hex.length & 1) == 1
        bin = [hex].pack("H*")
        mask = bin[0].ord
        mask |= mask >> 1
        mask |= mask >> 2
        mask |= mask >> 4

        loop do
          rnd = random_bytes(bin.length)
          rnd[0] = (rnd[0].ord & mask).chr
          return rnd.unpack("H*")[0].hex if rnd < bin
        end
      else
        raise NotImplementedError
      end
    end

    def uuid
      ary = random_bytes(16).unpack("nnnnnnnn")
      ary[3] = (ary[3] & 0x0fff) | 0x4000
      ary[4] = (ary[4] & 0x3fff) | 0x8000
      "%04x%04x-%04x-%04x-%04x-%04x%04x%04x" % ary
    end
  end
end
