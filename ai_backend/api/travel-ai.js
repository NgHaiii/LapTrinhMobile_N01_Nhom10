const GROQ_MODELS = [
  'llama-3.1-8b-instant',
  'llama-3.3-70b-versatile',
];

const REQUEST_TIMEOUT_MS = 15000;
const MAX_HISTORY_MESSAGES = 10;

export default async function handler(request, response) {
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (request.method === 'OPTIONS') {
    return response.status(200).end();
  }

  if (request.method !== 'POST') {
    return response.status(405).json({
      error: 'Method not allowed',
    });
  }

  const apiKey = process.env.GROQ_API_KEY;

  if (!apiKey) {
    return response.status(500).json({
      error: 'Server chưa cấu hình GROQ_API_KEY.',
    });
  }

  try {
    const body = parseBody(request.body);
    const message = String(body.message || '').trim();
    const places = Array.isArray(body.places) ? body.places : [];
    const history = Array.isArray(body.history) ? body.history : [];

    if (message.length < 2) {
      return response.status(400).json({
        error: 'Câu hỏi quá ngắn.',
      });
    }

    if (message.length > 1200) {
      return response.status(400).json({
        error: 'Câu hỏi quá dài.',
      });
    }

    const systemPrompt = buildSystemPrompt(places);
    const result = await askGroqWithFallback(
      apiKey,
      systemPrompt,
      message,
      history,
    );

    return response.status(200).json({
      answer: result.answer,
      model: result.model,
    });
  } catch (error) {
    return response.status(500).json({
      error: 'AI đang tạm thời không phản hồi.',
      detail: String(error),
    });
  }
}

function parseBody(body) {
  if (!body) return {};

  if (typeof body === 'string') {
    try {
      return JSON.parse(body);
    } catch (_) {
      return {};
    }
  }

  return body;
}

function buildSystemPrompt(places) {
  const placesContext = places
    .slice(0, 20)
    .map((place, index) => {
      return [
        `${index + 1}. ${place.name || 'Chưa có tên'}`,
        `Khu vực: ${place.district || 'Chưa rõ'}, ${place.province || 'Chưa rõ'}`,
        `Loại: ${place.category || 'Chưa phân loại'}`,
        `Địa chỉ: ${place.address || 'Chưa cập nhật'}`,
        `Mô tả: ${place.description || 'Chưa cập nhật mô tả'}`,
        `Giá vé: ${place.ticketPrice || 0}`,
        `Đánh giá: ${place.rating || 0}`,
        `Tags: ${Array.isArray(place.tags) ? place.tags.join(', ') : ''}`,
      ].join('\n');
    })
    .join('\n\n');

  return `
Bạn là TravelHub AI, trợ lý du lịch chuyên nghiệp trong ứng dụng đặt phòng và du lịch tại Việt Nam.

Nhiệm vụ:
- Tư vấn địa điểm du lịch, lịch trình, ăn uống, di chuyển, thời điểm đi phù hợp.
- Trả lời cụ thể như một tư vấn viên du lịch thật, không nói chung chung.
- Ưu tiên địa điểm trong dữ liệu TravelHub nếu phù hợp.
- Nếu TravelHub chưa có dữ liệu phù hợp, được dùng kiến thức du lịch phổ biến và nói rõ là gợi ý tham khảo.
- Không bịa trạng thái phòng, giá phòng, voucher, thanh toán hoặc tình trạng còn phòng.
- Không nhắc rằng bạn là AI model.

Quy tắc bám sát hội thoại:
- Luôn đọc lịch sử hội thoại trước khi trả lời.
- Nếu người dùng trả lời ngắn như "có", "tiếp", "được", "ok", "gợi ý thêm", hãy hiểu là họ muốn tiếp tục chủ đề gần nhất.
- Không tự đổi sang thành phố, tỉnh hoặc địa điểm khác nếu người dùng chưa yêu cầu.
- Nếu đang tư vấn Đà Nẵng, câu trả lời tiếp theo vẫn phải xoay quanh Đà Nẵng.
- Nếu đang tư vấn lịch trình 3 ngày, câu trả lời tiếp theo phải bổ sung hoặc tinh chỉnh lịch trình 3 ngày đó.
- Nếu người dùng hỏi thêm về chi phí, ăn uống, phương tiện, khách sạn, hãy trả lời trong cùng địa điểm/lịch trình gần nhất.
- Chỉ đổi chủ đề khi người dùng nói rõ địa điểm hoặc nhu cầu mới.

Phong cách trả lời:
- Luôn dùng tiếng Việt.
- Thân thiện, dễ hiểu, phù hợp app mobile.
- Không dùng Markdown.
- Không dùng dấu **, *, #, \`\`\` hoặc ký hiệu định dạng.
- Nếu cần liệt kê, dùng số thứ tự 1., 2., 3. hoặc gạch đầu dòng "-".
- Có tiêu đề ngắn, dễ đọc.
- Nên có địa điểm cụ thể, lý do chọn, thời điểm đi, chi phí ước tính.
- Cuối câu trả lời chỉ hỏi thêm tối đa 1 câu ngắn nếu cần cá nhân hóa.

Thông tin mặc định nếu người dùng chưa nói rõ:
- Số người: 2 người.
- Ngân sách: trung bình.
- Phong cách: cân bằng giữa tham quan, ăn uống, nghỉ ngơi.
- Di chuyển: taxi hoặc xe máy tùy địa điểm.
- Lịch trình: không quá dày.

Nếu người dùng hỏi lịch trình, trả lời theo cấu trúc:
1. Tóm tắt nhanh chuyến đi
2. Lịch trình chi tiết theo ngày
   - Sáng:
   - Trưa:
   - Chiều:
   - Tối:
3. Chi phí dự kiến
4. Lưu ý thực tế
5. Một câu hỏi ngắn để cá nhân hóa thêm

Nếu người dùng hỏi "đi đâu", trả lời theo cấu trúc:
1. 3-5 địa điểm nên đi
2. Vì sao phù hợp
3. Nên đi vào thời điểm nào
4. Gợi ý kết hợp lịch trình ngắn
5. Một câu hỏi ngắn để cá nhân hóa thêm

Dữ liệu địa điểm hiện có trong TravelHub:
${placesContext || 'Hiện chưa có dữ liệu địa điểm trong TravelHub.'}
`;
}

async function askGroqWithFallback(apiKey, systemPrompt, userMessage, history) {
  const errors = [];

  for (const model of GROQ_MODELS) {
    try {
      const answer = await askGroq(
        apiKey,
        model,
        systemPrompt,
        userMessage,
        history,
      );

      const clean = cleanAnswer(answer);

      if (clean.length >= 40) {
        return {
          answer: clean,
          model,
        };
      }

      errors.push(`${model}: câu trả lời quá ngắn.`);
    } catch (error) {
      errors.push(`${model}: ${String(error)}`);
    }
  }

  throw new Error(errors.join('\n\n'));
}

async function askGroq(apiKey, model, systemPrompt, userMessage, history) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const groqResponse = await fetch(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        method: 'POST',
        signal: controller.signal,
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: 'system',
              content: systemPrompt,
            },
            ...normalizeHistory(history),
            {
              role: 'user',
              content: userMessage,
            },
          ],
          temperature: 0.68,
          max_tokens: 1200,
        }),
      },
    );

    const responseText = await groqResponse.text();

    if (!groqResponse.ok) {
      throw new Error(responseText);
    }

    const data = JSON.parse(responseText);

    return data.choices?.[0]?.message?.content?.trim() || '';
  } finally {
    clearTimeout(timer);
  }
}

function normalizeHistory(history) {
  return history
    .slice(-MAX_HISTORY_MESSAGES)
    .map((item) => {
      const role = item.role === 'assistant' ? 'assistant' : 'user';
      const content = String(item.content || '').trim().slice(0, 1500);

      return {
        role,
        content,
      };
    })
    .filter((item) => item.content.length > 0);
}

function cleanAnswer(text) {
  return String(text || '')
    .replace(/```[\s\S]*?```/g, '')
    .replace(/\*\*(.*?)\*\*/g, '$1')
    .replace(/\*(.*?)\*/g, '$1')
    .replace(/^#{1,6}\s+/gm, '')
    .replace(/^\s*[-*]\s+/gm, '- ')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}