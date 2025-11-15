import {
  Injectable,
  InternalServerErrorException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { GoogleGenerativeAI } from '@google/generative-ai';

@Injectable()
export class AppService {
  private readonly modelName = 'gemini-2.5-flash';

  async requestProfessorResponse(question: string) {
    const apiKey = process.env.GEMINI_API_KEY;
    const prompt = this.buildPrompt(question);
    const client = new GoogleGenerativeAI(apiKey!);
    const model = client.getGenerativeModel({
      model: this.modelName,
    });

    try {
      const result = await model.generateContent(prompt);
      const text = result.response?.text()?.trim();

      if (!text) {
        throw new InternalServerErrorException(
          'O modelo do Gemini não retornou uma resposta para esta pergunta.',
        );
      }
      return {
        question,
        explanation: text,
      };
    } catch (error: unknown) {
      if (
        error &&
        typeof error === 'object' &&
        'status' in error &&
        error.status === 503
      ) {
        throw new ServiceUnavailableException(
          'O modelo do Gemini está temporariamente sobrecarregado. Por favor, tente novamente em alguns instantes.',
        );
      }

      if (error instanceof Error) {
        throw new InternalServerErrorException(
          `Erro ao processar a solicitação: ${error.message}`,
        );
      }

      throw new InternalServerErrorException(
        'Erro desconhecido ao processar a solicitação.',
      );
    }
  }

  private buildPrompt(question: string) {
    return [
      'Você é um professor experiente explicando conteúdos de forma clara e motivadora.',
      'Estruture a resposta com seções numeradas: (1) Visão geral, (2) Conceitos-chave, (3) Exemplos ou analogias, (4) Exercícios práticos, (5) Próximos passos.',
      'Deixe explícito que você está atuando como professor e fale diretamente com o estudante.',
      `Pergunta do estudante: ${question}.`,
      'Responda em português simples, mantendo tom acolhedor e encorajador.',
    ].join('\n');
  }
}
