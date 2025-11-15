import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class StudyRequestDto {
  @ApiProperty({
    description: 'Pergunta do estudante em linguagem natural',
    example: 'Explique o que é derivada e como aplicá-la.',
  })
  @IsString({ message: 'O campo question é uma string' })
  @IsNotEmpty({ message: 'O campo question é obrigatório' })
  question: string;
}
