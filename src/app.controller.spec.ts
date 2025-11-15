import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { AppService } from './app.service';

describe('AppController', () => {
  let appController: AppController;
  let appService: AppService;

  beforeEach(async () => {
    const mockService = {
      requestProfessorResponse: jest.fn(),
    } as Partial<AppService>;

    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [{ provide: AppService, useValue: mockService }],
    }).compile();

    appController = app.get<AppController>(AppController);
    appService = app.get<AppService>(AppService);
  });

  describe('askProfessor', () => {
    it('should delegate to AppService when question is provided', async () => {
      const expectedResponse = {
        question: 'O que é derivada?',
        explanation: 'ok',
      };
      jest
        .spyOn(appService, 'requestProfessorResponse')
        .mockResolvedValue(expectedResponse);

      await expect(
        appController.askProfessor({ question: 'O que é derivada?' }),
      ).resolves.toEqual(expectedResponse);
      expect(appService.requestProfessorResponse).toHaveBeenCalledWith(
        'O que é derivada?',
      );
    });

    it('should throw when question is missing', async () => {
      await expect(
        appController.askProfessor({ question: '   ' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });
});
