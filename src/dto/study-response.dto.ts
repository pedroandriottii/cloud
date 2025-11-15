import { ApiProperty } from '@nestjs/swagger';

export class StudyResponseDto {
  @ApiProperty({
    description: 'Pergunta original enviada pelo estudante',
    example: 'Explique o que é derivada e como aplicá-la.',
  })
  question: string;

  @ApiProperty({
    description: 'Resposta formatada pelo professor virtual',
    example:
      '1) Visão geral... 2) Conceitos-chave... 3) Exemplos... 4) Exercícios... 5) Próximos passos...',
  })
  explanation: string;
}
